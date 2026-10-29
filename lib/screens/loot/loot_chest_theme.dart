import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'loot_models.dart';

/// Canonical 6-Tier Item & Chest Rarity definitions for AAA standard fantasy loot systems.
/// Common, Uncommon, Rare, Heroic, Mythic, Divine.
enum LootRarity {
  common,
  uncommon,
  rare,
  heroic,
  mythic,
  divine;

  String get displayName => switch (this) {
    LootRarity.common => 'Sıradan',
    LootRarity.uncommon => 'Sıradışı',
    LootRarity.rare => 'Nadir',
    LootRarity.heroic => 'Kahramanlık',
    LootRarity.mythic => 'Mistik',
    LootRarity.divine => 'İlahi',
  };

  String get englishName => switch (this) {
    LootRarity.common => 'Common',
    LootRarity.uncommon => 'Uncommon',
    LootRarity.rare => 'Rare',
    LootRarity.heroic => 'Heroic',
    LootRarity.mythic => 'Mythic',
    LootRarity.divine => 'Divine',
  };

  String get badgeText => switch (this) {
    LootRarity.common => 'SIRADAN',
    LootRarity.uncommon => 'SIRADIŞI',
    LootRarity.rare => 'NADİR',
    LootRarity.heroic => 'KAHRAMANLIK',
    LootRarity.mythic => 'MİSTİK',
    LootRarity.divine => 'İLAHİ',
  };

  /// Primary rarity color strictly aligned with AppColors.
  Color get color => switch (this) {
    LootRarity.common => AppColors.rarityCommon,
    LootRarity.uncommon => AppColors.rarityUncommon,
    LootRarity.rare => AppColors.rarityRare,
    LootRarity.heroic => AppColors.gold,
    LootRarity.mythic => AppColors.rarityMythic,
    LootRarity.divine => const Color(0xFFE879F9),
  };

  /// Secondary accent color for luminous borders, highlights, and reticles.
  Color get accentColor => switch (this) {
    LootRarity.common => const Color(0xFFE5E7EB),
    LootRarity.uncommon => const Color(0xFF86EFAC),
    LootRarity.rare => const Color(0xFF93C5FD),
    LootRarity.heroic => AppColors.goldLight,
    LootRarity.mythic => const Color(0xFFFCA5A5),
    LootRarity.divine => const Color(0xFFF0ABFC),
  };

  /// Frame & boundary stroke color.
  Color get borderColor => switch (this) {
    LootRarity.common => AppColors.borderBright,
    LootRarity.uncommon => const Color(0xFF16A34A),
    LootRarity.rare => const Color(0xFF3B82F6),
    LootRarity.heroic => AppColors.warning,
    LootRarity.mythic => const Color(0xFFDC2626),
    LootRarity.divine => const Color(0xFFC084FC),
  };

  /// Normalized ambient glow intensity (0.0 to 1.0).
  double get glowIntensity => switch (this) {
    LootRarity.common => 0.30,
    LootRarity.uncommon => 0.45,
    LootRarity.rare => 0.60,
    LootRarity.heroic => 0.75,
    LootRarity.mythic => 0.88,
    LootRarity.divine => 1.00,
  };

  /// Tinted bloom / aura color computed from base color and glow intensity.
  Color get glowColor => color.withValues(alpha: glowIntensity);

  /// Outer aura blur radius (BoxShadow blur).
  double get glowBlurRadius => switch (this) {
    LootRarity.common => 10.0,
    LootRarity.uncommon => 14.0,
    LootRarity.rare => 20.0,
    LootRarity.heroic => 28.0,
    LootRarity.mythic => 36.0,
    LootRarity.divine => 48.0,
  };

  /// Ambient aura spread radius.
  double get glowSpreadRadius => switch (this) {
    LootRarity.common => 1.0,
    LootRarity.uncommon => 1.5,
    LootRarity.rare => 2.0,
    LootRarity.heroic => 3.0,
    LootRarity.mythic => 4.0,
    LootRarity.divine => 6.0,
  };

  /// Corner radius aligned with AppSpacing tokens.
  double get borderRadius => switch (this) {
    LootRarity.common => AppSpacing.radiusSm,
    LootRarity.uncommon => AppSpacing.radiusMd,
    LootRarity.rare => AppSpacing.radiusMd,
    LootRarity.heroic => AppSpacing.radiusLg,
    LootRarity.mythic => AppSpacing.radiusXl,
    LootRarity.divine => AppSpacing.radiusXxl,
  };

  /// Frosted glass blur sigma for BackdropFilter.
  double get glassBlurSigma => switch (this) {
    LootRarity.common => 8.0,
    LootRarity.uncommon => 10.0,
    LootRarity.rare => 14.0,
    LootRarity.heroic => 18.0,
    LootRarity.mythic => 24.0,
    LootRarity.divine => 32.0,
  };

  /// Precision gradient stops for high-fidelity chest & card backdrops.
  List<double> get gradientStops => switch (this) {
    LootRarity.common => const <double>[0.0, 0.50, 1.0],
    LootRarity.uncommon => const <double>[0.0, 0.45, 1.0],
    LootRarity.rare => const <double>[0.0, 0.40, 1.0],
    LootRarity.heroic => const <double>[0.0, 0.35, 1.0],
    LootRarity.mythic => const <double>[0.0, 0.30, 0.70, 1.0],
    LootRarity.divine => const <double>[0.0, 0.25, 0.65, 1.0],
  };

  /// Chime pitch multiplier for tactile reveal feedback.
  double get chimePitch => switch (this) {
    LootRarity.common => 1.00,
    LootRarity.uncommon => 1.15,
    LootRarity.rare => 1.30,
    LootRarity.heroic => 1.50,
    LootRarity.mythic => 1.75,
    LootRarity.divine => 2.00,
  };

  /// Thematic runic characters.
  List<String> get runicGlyphs => switch (this) {
    LootRarity.common => const <String>['ᛟ', 'ᚱ', 'ᚦ'],
    LootRarity.uncommon => const <String>['ᚨ', 'ᚾ', 'ᛁ'],
    LootRarity.rare => const <String>['ᚲ', 'ᛏ', 'ᛚ'],
    LootRarity.heroic => const <String>['ᛋ', 'ᚹ', 'ᛃ'],
    LootRarity.mythic => const <String>['ᛇ', 'ᛉ', 'ᛗ'],
    LootRarity.divine => const <String>['ᛯ', 'ᛰ', 'ᛱ', 'ᛲ'],
  };

  /// Parses arbitrary rarity string tokens.
  static LootRarity fromString(String? value) {
    final String val = (value ?? '').trim().toLowerCase();
    return switch (val) {
      'divine' || 'ilahi' || 'ebedi' || 'eternal' => LootRarity.divine,
      'mythic' || 'mistik' || 'efsanevi' || 'fabled' || 'legendary' => LootRarity.mythic,
      'heroic' || 'kahraman' || 'kahramanlık' || 'epic' => LootRarity.heroic,
      'rare' || 'nadir' => LootRarity.rare,
      'uncommon' || 'siradisi' || 'sıradışı' || 'advanced' => LootRarity.uncommon,
      _ => LootRarity.common,
    };
  }
}

/// 2027 Aion 2 Mobile Loot Chest Tiers reflecting AAA modern dark/high-fantasy standards.
enum LootChestTier {
  common,  // Weathered Iron & Oak
  rare,    // Polished Cobalt & Silver
  heroic,  // Gilded Gold & Crimson Velvet
  fabled,  // Celestial Cyan Crystal & Platinum
  eternal; // Abyssal Void Obsidian with burning purple runic chains

  /// Maps canonical chest tier to unified LootRarity.
  LootRarity get rarity => switch (this) {
    LootChestTier.common => LootRarity.common,
    LootChestTier.rare => LootRarity.rare,
    LootChestTier.heroic => LootRarity.heroic,
    LootChestTier.fabled => LootRarity.mythic,
    LootChestTier.eternal => LootRarity.divine,
  };

  String get displayName => switch (this) {
    LootChestTier.common => 'Demir ve Meşe Sandığı',
    LootChestTier.rare => 'Kobalt ve Gümüş Sandığı',
    LootChestTier.heroic => 'Altın ve Yakut Sandığı',
    LootChestTier.fabled => 'Semavi Kristal Sandığı',
    LootChestTier.eternal => 'Uçurum Obsidyeni Sandığı',
  };

  String get englishName => switch (this) {
    LootChestTier.common => 'Weathered Iron & Oak',
    LootChestTier.rare => 'Polished Cobalt & Silver',
    LootChestTier.heroic => 'Gilded Gold & Crimson Velvet',
    LootChestTier.fabled => 'Celestial Cyan Crystal & Platinum',
    LootChestTier.eternal => 'Abyssal Void Obsidian & Burning Purple Runic Chains',
  };

  String get tierBadge => switch (this) {
    LootChestTier.common => 'SIRADAN',
    LootChestTier.rare => 'NADİR',
    LootChestTier.heroic => 'KAHRAMANLIK',
    LootChestTier.fabled => 'EFSANEVİ',
    LootChestTier.eternal => 'EBEDİ',
  };

  Color get primaryColor => switch (this) {
    LootChestTier.common => const Color(0xFF8D6E63), // Weathered Oak
    LootChestTier.rare => AppColors.info,            // Polished Cobalt
    LootChestTier.heroic => const Color(0xFFBE123C), // Crimson Velvet
    LootChestTier.fabled => AppColors.accentCyan,    // Celestial Cyan Crystal
    LootChestTier.eternal => AppColors.accentPurple, // Burning Purple Rune
  };

  Color get secondaryColor => switch (this) {
    LootChestTier.common => const Color(0xFF4B5563), // Weathered Iron
    LootChestTier.rare => const Color(0xFFE2E8F0),   // Polished Silver
    LootChestTier.heroic => AppColors.gold,          // Gilded Gold
    LootChestTier.fabled => const Color(0xFFF8FAFC), // Shimmering Platinum
    LootChestTier.eternal => AppColors.bgDeep,       // Abyssal Void Obsidian
  };

  Color get accentColor => switch (this) {
    LootChestTier.common => const Color(0xFFD7CCC8),
    LootChestTier.rare => const Color(0xFF38BDF8),
    LootChestTier.heroic => AppColors.goldLight,
    LootChestTier.fabled => const Color(0xFF22D3EE),
    LootChestTier.eternal => const Color(0xFFC084FC),
  };

  Color get glowColor => switch (this) {
    LootChestTier.common => const Color(0xFF795548).withValues(alpha: 0.35),
    LootChestTier.rare => AppColors.info.withValues(alpha: 0.55),
    LootChestTier.heroic => const Color(0xFFE11D48).withValues(alpha: 0.65),
    LootChestTier.fabled => AppColors.accentCyan.withValues(alpha: 0.75),
    LootChestTier.eternal => AppColors.accentPurple.withValues(alpha: 0.85),
  };

  Color get borderColor => switch (this) {
    LootChestTier.common => AppColors.borderBright,
    LootChestTier.rare => const Color(0xFF60A5FA),
    LootChestTier.heroic => AppColors.gold,
    LootChestTier.fabled => const Color(0xFF67E8F9),
    LootChestTier.eternal => const Color(0xFFE879F9),
  };

  Color get chainColor => switch (this) {
    LootChestTier.eternal => const Color(0xFF7E22CE),
    _ => Colors.transparent,
  };

  List<String> get runicGlyphs => switch (this) {
    LootChestTier.common => const <String>['ᛟ', 'ᚱ', 'ᚦ'],
    LootChestTier.rare => const <String>['ᚲ', 'ᛏ', 'ᛚ'],
    LootChestTier.heroic => const <String>['ᛋ', 'ᚹ', 'ᛃ'],
    LootChestTier.fabled => const <String>['ᛇ', 'ᛉ', 'ᛗ'],
    LootChestTier.eternal => const <String>['ᛯ', 'ᛰ', 'ᛱ', 'ᛲ'],
  };

  double get chimePitch => switch (this) {
    LootChestTier.common => 1.0,
    LootChestTier.rare => 1.25,
    LootChestTier.heroic => 1.5,
    LootChestTier.fabled => 1.75,
    LootChestTier.eternal => 2.0,
  };

  double get glowIntensity => rarity.glowIntensity;
  double get glowBlurRadius => rarity.glowBlurRadius;
  double get glowSpreadRadius => rarity.glowSpreadRadius;
  double get borderRadius => rarity.borderRadius;
  double get glassBlurSigma => rarity.glassBlurSigma;
  List<double> get gradientStops => rarity.gradientStops;
}

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
    this.tier = LootChestTier.common,
    this.materialDescription = '',
    this.runicGlyphs = const <String>['ᛟ', 'ᚱ', 'ᚦ'],
    this.glowIntensity,
    this.gradientStops = const <double>[0.0, 0.45, 1.0],
    this.borderRadius = AppSpacing.radiusLg,
    this.glassBlurSigma = 16.0,
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
  final LootChestTier tier;
  final String materialDescription;
  final List<String> runicGlyphs;
  final double? glowIntensity;
  final List<double> gradientStops;
  final double borderRadius;
  final double glassBlurSigma;

  bool get isEternal => tier == LootChestTier.eternal;
  bool get isFabled => tier == LootChestTier.fabled;
  bool get isHeroic => tier == LootChestTier.heroic;
  bool get isRare => tier == LootChestTier.rare;
  bool get isCommon => tier == LootChestTier.common;
  Color get glowColor => tier.glowColor;
  double get effectiveGlowIntensity => glowIntensity ?? tier.glowIntensity;
  LootRarity get rarity => tier.rarity;

  /// High-fantasy AAA BoxShadow array based on tier glow and dark elevation.
  List<BoxShadow> get cardShadows => <BoxShadow>[
    BoxShadow(
      color: glowColor.withValues(
        alpha: (effectiveGlowIntensity * 0.45).clamp(0.0, 1.0),
      ),
      blurRadius: tier.glowBlurRadius,
      spreadRadius: tier.glowSpreadRadius,
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.65),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  /// Standard AAA Glassmorphic BoxDecoration
  BoxDecoration get glassDecoration => BoxDecoration(
    borderRadius: BorderRadius.circular(borderRadius),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      stops: gradientStops.length == 3
          ? gradientStops
          : const <double>[0.0, 0.45, 1.0],
      colors: <Color>[
        radialCenter.withValues(alpha: 0.35),
        radialEdge.withValues(alpha: 0.65),
        AppColors.bgDeep.withValues(alpha: 0.85),
      ],
    ),
    border: Border.all(
      color: borderColor.withValues(alpha: 0.55),
      width: 1.2,
    ),
    boxShadow: cardShadows,
  );

  /// Fullscreen ambient radial aura gradient for chest reveals.
  RadialGradient get ambientAuraGradient => RadialGradient(
    center: Alignment.center,
    radius: 0.85,
    stops: gradientStops.length == 3
        ? gradientStops
        : const <double>[0.0, 0.50, 1.0],
    colors: <Color>[
      radialCenter.withValues(
        alpha: (effectiveGlowIntensity * 0.55).clamp(0.0, 1.0),
      ),
      radialEdge.withValues(
        alpha: (effectiveGlowIntensity * 0.25).clamp(0.0, 1.0),
      ),
      Colors.transparent,
    ],
  );

  /// Consistent typography tokens aligned with AppTextStyles.
  TextStyle get titleStyle => AppTextStyles.h2.copyWith(
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w800,
  );

  TextStyle get subtitleStyle => AppTextStyles.caption.copyWith(
    color: AppColors.textSecondary,
  );

  TextStyle get badgeStyle => AppTextStyles.label.copyWith(
    color: accentColor,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.8,
  );
}

/// The Canonical 2027 Aion 2 Mobile Chest Tier Themes:
const LootChestTheme kCommonChestTheme = LootChestTheme(
  id: 'tier_common',
  assetPath: 'assets/chest/kasaokyanus.png',
  displayName: 'Demir ve Meşe Sandığı',
  radialCenter: Color(0xFF5D4037),
  radialEdge: Color(0xFF1E140F),
  borderColor: AppColors.borderBright,
  accentColor: Color(0xFFD7CCC8),
  fullscreenBgStart: Color(0xFF2E1C14),
  fullscreenBgEnd: Color(0xFF0F0805),
  shortDescription: 'Zamanın yıprattığı meşe kaplamalı dayanıklı demir sandık.',
  tier: LootChestTier.common,
  materialDescription: 'Weathered Iron & Oak',
  runicGlyphs: <String>['ᛟ', 'ᚱ', 'ᚦ'],
  glowIntensity: 0.35,
  gradientStops: <double>[0.0, 0.50, 1.0],
  borderRadius: AppSpacing.radiusSm,
  glassBlurSigma: 8.0,
);

const LootChestTheme kUncommonChestTheme = LootChestTheme(
  id: 'tier_uncommon',
  assetPath: 'assets/chest/kasaamazon.png',
  displayName: 'Orman ve Zümrüt Sandığı',
  radialCenter: Color(0xFF15803D),
  radialEdge: Color(0xFF052E16),
  borderColor: AppColors.rarityUncommon,
  accentColor: Color(0xFF86EFAC),
  fullscreenBgStart: Color(0xFF14532D),
  fullscreenBgEnd: Color(0xFF052E16),
  shortDescription: 'Doğanın kadim zümrütleriyle işlenmiş sağlam orman sandığı.',
  tier: LootChestTier.common,
  materialDescription: 'Tempered Emerald & Sylvan Wood',
  runicGlyphs: <String>['ᚨ', 'ᚾ', 'ᛁ'],
  glowIntensity: 0.45,
  gradientStops: <double>[0.0, 0.45, 1.0],
  borderRadius: AppSpacing.radiusMd,
  glassBlurSigma: 10.0,
);

const LootChestTheme kRareChestTheme = LootChestTheme(
  id: 'tier_rare',
  assetPath: 'assets/chest/kasauzay.png',
  displayName: 'Kobalt ve Gümüş Sandığı',
  radialCenter: Color(0xFF1D4ED8),
  radialEdge: Color(0xFF0B1938),
  borderColor: Color(0xFF60A5FA),
  accentColor: Color(0xFF38BDF8),
  fullscreenBgStart: Color(0xFF0F1E4A),
  fullscreenBgEnd: Color(0xFF040816),
  shortDescription: 'Cilalı kobalt plaka ve saf gümüş oymalarla dövülmüş sandık.',
  tier: LootChestTier.rare,
  materialDescription: 'Polished Cobalt & Silver',
  runicGlyphs: <String>['ᚲ', 'ᛏ', 'ᛚ'],
  glowIntensity: 0.55,
  gradientStops: <double>[0.0, 0.40, 1.0],
  borderRadius: AppSpacing.radiusMd,
  glassBlurSigma: 14.0,
);

const LootChestTheme kHeroicChestTheme = LootChestTheme(
  id: 'tier_heroic',
  assetPath: 'assets/chest/kasalav.png',
  displayName: 'Altın ve Yakut Sandığı',
  radialCenter: Color(0xFFBE123C),
  radialEdge: Color(0xFF36040F),
  borderColor: AppColors.gold,
  accentColor: AppColors.goldLight,
  fullscreenBgStart: Color(0xFF4C0519),
  fullscreenBgEnd: Color(0xFF120106),
  shortDescription: 'Yaldızlı saf altın kabartmalar ve derin kırmızı yakut kadife astar.',
  tier: LootChestTier.heroic,
  materialDescription: 'Gilded Gold & Crimson Velvet',
  runicGlyphs: <String>['ᛋ', 'ᚹ', 'ᛃ'],
  glowIntensity: 0.70,
  gradientStops: <double>[0.0, 0.35, 1.0],
  borderRadius: AppSpacing.radiusLg,
  glassBlurSigma: 18.0,
);

const LootChestTheme kFabledChestTheme = LootChestTheme(
  id: 'tier_fabled',
  assetPath: 'assets/chest/kasabuzdevri.png',
  displayName: 'Semavi Kristal Sandığı',
  radialCenter: Color(0xFF06B6D4),
  radialEdge: Color(0xFF042B38),
  borderColor: Color(0xFF67E8F9),
  accentColor: Color(0xFF22D3EE),
  fullscreenBgStart: Color(0xFF083344),
  fullscreenBgEnd: Color(0xFF011018),
  shortDescription: 'Göksel camgöbeği kristal prizmalar ve dövme platin gövde.',
  tier: LootChestTier.fabled,
  materialDescription: 'Celestial Cyan Crystal & Platinum',
  runicGlyphs: <String>['ᛇ', 'ᛉ', 'ᛗ'],
  glowIntensity: 0.85,
  gradientStops: <double>[0.0, 0.30, 0.70, 1.0],
  borderRadius: AppSpacing.radiusXl,
  glassBlurSigma: 24.0,
);

const LootChestTheme kEternalChestTheme = LootChestTheme(
  id: 'tier_eternal',
  assetPath: 'assets/chest/kasawitch.png',
  displayName: 'Uçurum Obsidyeni Sandığı',
  radialCenter: Color(0xFF7E22CE),
  radialEdge: Color(0xFF18032E),
  borderColor: Color(0xFFE879F9),
  accentColor: Color(0xFFC084FC),
  fullscreenBgStart: Color(0xFF2E0854),
  fullscreenBgEnd: Color(0xFF070110),
  shortDescription: 'Uçurum obsidyeni ve alev alev yanan mor rünik zincirlerle mühürlü.',
  tier: LootChestTier.eternal,
  materialDescription: 'Abyssal Void Obsidian with Burning Purple Runic Chains',
  runicGlyphs: <String>['ᛯ', 'ᛰ', 'ᛱ', 'ᛲ'],
  glowIntensity: 1.00,
  gradientStops: <double>[0.0, 0.25, 0.65, 1.0],
  borderRadius: AppSpacing.radiusXxl,
  glassBlurSigma: 32.0,
);

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
  tier: LootChestTier.heroic,
  materialDescription: 'Gilded Gold & Crimson Velvet',
  glowIntensity: 0.70,
  gradientStops: <double>[0.0, 0.35, 1.0],
  borderRadius: AppSpacing.radiusLg,
  glassBlurSigma: 18.0,
);

const List<LootChestTheme> kLootChestThemes = <LootChestTheme>[
  kCommonChestTheme,
  kUncommonChestTheme,
  kRareChestTheme,
  kHeroicChestTheme,
  kFabledChestTheme,
  kEternalChestTheme,
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
    tier: LootChestTier.eternal,
    materialDescription: 'Abyssal Void Obsidian with Burning Purple Runic Chains',
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
    tier: LootChestTier.fabled,
    materialDescription: 'Celestial Cyan Crystal & Platinum',
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
    tier: LootChestTier.rare,
    materialDescription: 'Polished Cobalt & Silver',
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
    tier: LootChestTier.rare,
    materialDescription: 'Polished Cobalt & Silver',
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
    tier: LootChestTier.common,
    materialDescription: 'Weathered Iron & Oak',
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
    tier: LootChestTier.heroic,
    materialDescription: 'Gilded Gold & Crimson Velvet',
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
    tier: LootChestTier.common,
    materialDescription: 'Weathered Iron & Oak',
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
    tier: LootChestTier.fabled,
    materialDescription: 'Celestial Cyan Crystal & Platinum',
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
    tier: LootChestTier.common,
    materialDescription: 'Weathered Iron & Oak',
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
    tier: LootChestTier.heroic,
    materialDescription: 'Gilded Gold & Crimson Velvet',
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
    tier: LootChestTier.rare,
    materialDescription: 'Polished Cobalt & Silver',
  ),
];

/// Server theme_id -> chest art / copy theme.
const Map<String, String> kLootThemeIdToChestArt = <String, String>{
  'weapon': 'kasakorsan',
  'armor': 'kasabuzdevri',
  'jewelry': 'kasacevher',
  'material': 'kasasekerleme',
  'dungeon': 'kasadeniz',
  'epic_weapon': 'kasauzay',
  'epic_armor': 'kasaamazon',
  'prestige': 'kasawitch',
  'starter': 'kasamarshmallow',
  'craft': 'kasalav',
  'consumable': 'kasaokyanus',
  'mid_gear': 'kasakorsan',
  'tier_common': 'tier_common',
  'tier_uncommon': 'tier_uncommon',
  'tier_rare': 'tier_rare',
  'tier_heroic': 'tier_heroic',
  'tier_fabled': 'tier_fabled',
  'tier_eternal': 'tier_eternal',
  'tier_mythic': 'tier_fabled',
  'tier_divine': 'tier_eternal',
};

LootChestTheme lootChestThemeForTier(LootChestTier tier) {
  return switch (tier) {
    LootChestTier.common => kCommonChestTheme,
    LootChestTier.rare => kRareChestTheme,
    LootChestTier.heroic => kHeroicChestTheme,
    LootChestTier.fabled => kFabledChestTheme,
    LootChestTier.eternal => kEternalChestTheme,
  };
}

/// Resolves dedicated LootChestTheme for a canonical LootRarity.
LootChestTheme themeForRarity(LootRarity rarity) {
  return switch (rarity) {
    LootRarity.common => kCommonChestTheme,
    LootRarity.uncommon => kUncommonChestTheme,
    LootRarity.rare => kRareChestTheme,
    LootRarity.heroic => kHeroicChestTheme,
    LootRarity.mythic => kFabledChestTheme,
    LootRarity.divine => kEternalChestTheme,
  };
}

LootChestTier resolveChestTier({
  String? boxId,
  String? themeId,
  int? price,
  String? name,
  String? rarity,
}) {
  final String combined =
      '${boxId ?? ''} ${themeId ?? ''} ${name ?? ''} ${rarity ?? ''}'.toLowerCase();

  if (combined.contains('divine') ||
      combined.contains('eternal') ||
      combined.contains('witch') ||
      combined.contains('ebedi') ||
      combined.contains('ilahi') ||
      combined.contains('abyssal') ||
      combined.contains('obsidian') ||
      combined.contains('void')) {
    return LootChestTier.eternal;
  }
  if (combined.contains('fabled') ||
      combined.contains('mythic') ||
      combined.contains('mistik') ||
      combined.contains('crystal') ||
      combined.contains('buz') ||
      combined.contains('efsanevi') ||
      combined.contains('celestial') ||
      combined.contains('cyan') ||
      combined.contains('uzay')) {
    return LootChestTier.fabled;
  }
  if (combined.contains('heroic') ||
      combined.contains('gold') ||
      combined.contains('lav') ||
      combined.contains('kahraman') ||
      combined.contains('gilded') ||
      combined.contains('crimson') ||
      combined.contains('velvet') ||
      combined.contains('epic')) {
    return LootChestTier.heroic;
  }
  if (combined.contains('rare') ||
      combined.contains('cobalt') ||
      combined.contains('silver') ||
      combined.contains('nadir') ||
      combined.contains('deniz') ||
      combined.contains('okyanus') ||
      combined.contains('seker')) {
    return LootChestTier.rare;
  }

  if (price != null) {
    if (price >= 1000) return LootChestTier.eternal;
    if (price >= 500) return LootChestTier.fabled;
    if (price >= 250) return LootChestTier.heroic;
    if (price >= 100) return LootChestTier.rare;
  }

  return LootChestTier.common;
}

/// Resolves LootRarity directly from arbitrary inputs or resolved chest tier.
LootRarity resolveLootRarity({
  String? rarity,
  String? boxId,
  String? themeId,
  int? price,
  String? name,
}) {
  if (rarity != null && rarity.isNotEmpty) {
    return LootRarity.fromString(rarity);
  }
  return resolveChestTier(
    boxId: boxId,
    themeId: themeId,
    price: price,
    name: name,
    rarity: rarity,
  ).rarity;
}

LootChestTheme resolveLootChestTheme({
  String? boxId,
  String? artAsset,
  int? themeIndex,
  String? themeId,
}) {
  if (themeId != null && themeId.isNotEmpty) {
    final String? artKey = kLootThemeIdToChestArt[themeId];
    if (artKey != null) {
      for (final LootChestTheme theme in kLootChestThemes) {
        if (theme.id == artKey) return theme;
      }
    }
  }

  if (artAsset != null && artAsset.isNotEmpty) {
    final String normalized = artAsset.toLowerCase();
    for (final LootChestTheme theme in kLootChestThemes) {
      if (normalized.contains(theme.id)) {
        return theme;
      }
    }
  }

  if (boxId != null && boxId.isNotEmpty) {
    final String normalized = boxId.toLowerCase();
    for (final LootChestTheme theme in kLootChestThemes) {
      if (normalized.contains(theme.id)) {
        return theme;
      }
    }
  }

  if (themeIndex != null &&
      themeIndex >= 0 &&
      themeIndex < kLootChestThemes.length) {
    return kLootChestThemes[themeIndex];
  }

  return kDefaultLootChestTheme;
}

int lootThemeIndexForBox(LootBoxView box) {
  return box.displayOrder > 0 ? box.displayOrder - 1 : 0;
}

String lootBoxDisplayName({
  required LootBoxView box,
  required LootChestTheme theme,
  required int themeIndex,
}) {
  if (themeIndex >= 0 && themeIndex < kLootChestThemes.length) {
    return theme.displayName;
  }
  if (theme.id != kDefaultLootChestTheme.id) {
    return theme.displayName;
  }
  return box.name;
}

String lootBoxSubtitle({
  required LootBoxView box,
  required LootChestTheme theme,
  required int themeIndex,
}) {
  if (themeIndex >= 0 &&
      themeIndex < kLootChestThemes.length &&
      theme.shortDescription.isNotEmpty) {
    return theme.shortDescription;
  }
  if (theme.id != kDefaultLootChestTheme.id &&
      theme.shortDescription.isNotEmpty) {
    return theme.shortDescription;
  }
  return box.description;
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
