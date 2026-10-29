import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/social_theme_tokens.dart';

/// Authentic 2027 Aion 2 Social & Progression Reward Types.
enum SocialRewardType {
  celestialArchonWings,
  mythicDaevaChest,
  abyssCrystal,
  ancientEnchantmentStone,
  factionHonorInsignia;

  String get displayName => switch (this) {
        SocialRewardType.celestialArchonWings => 'Celestial Archon Wings',
        SocialRewardType.mythicDaevaChest => 'Mythic Daeva Chest',
        SocialRewardType.abyssCrystal => 'Abyss Crystal',
        SocialRewardType.ancientEnchantmentStone => 'Ancient Enchantment Stone',
        SocialRewardType.factionHonorInsignia => 'Faction Honor Insignia',
      };

  String get subtitle => switch (this) {
        SocialRewardType.celestialArchonWings => 'Ethereal flight relics of the High Daeva',
        SocialRewardType.mythicDaevaChest => 'Sealed vault containing celestial treasure',
        SocialRewardType.abyssCrystal => 'Pure condensed aether from the Core Abyss',
        SocialRewardType.ancientEnchantmentStone => 'Arcane monolith infused with primordial power',
        SocialRewardType.factionHonorInsignia => 'Medallion of valor awarded to champion legionaries',
      };

  Color get primaryColor => switch (this) {
        SocialRewardType.celestialArchonWings => SocialThemeTokens.aetherCyan,
        SocialRewardType.mythicDaevaChest => SocialThemeTokens.celestialGold,
        SocialRewardType.abyssCrystal => SocialThemeTokens.aetherBlue,
        SocialRewardType.ancientEnchantmentStone => SocialThemeTokens.daevaPrismViolet,
        SocialRewardType.factionHonorInsignia => SocialThemeTokens.balaurFlame,
      };

  Color get secondaryColor => switch (this) {
        SocialRewardType.celestialArchonWings => SocialThemeTokens.daevaPrismCyan,
        SocialRewardType.mythicDaevaChest => SocialThemeTokens.celestialGoldDark,
        SocialRewardType.abyssCrystal => SocialThemeTokens.aetherCyan,
        SocialRewardType.ancientEnchantmentStone => SocialThemeTokens.aetherCyan,
        SocialRewardType.factionHonorInsignia => SocialThemeTokens.balaurRuby,
      };

  Color get accentGlow => switch (this) {
        SocialRewardType.celestialArchonWings => SocialThemeTokens.celestialGoldLight,
        SocialRewardType.mythicDaevaChest => SocialThemeTokens.celestialAmber,
        SocialRewardType.abyssCrystal => SocialThemeTokens.aetherCyanLight,
        SocialRewardType.ancientEnchantmentStone => SocialThemeTokens.asmodianViolet,
        SocialRewardType.factionHonorInsignia => SocialThemeTokens.celestialGold,
      };

  /// Sequential integer identifier for GLSL shader uniform dispatch (0..4).
  int get shaderId => index;

  /// Floating point representation for shader uniform buffer.
  double get shaderTypeFloat => index.toDouble();

  /// Canonical progression rarity tier for this reward archetype.
  SocialRewardRarity get defaultRarity => switch (this) {
        SocialRewardType.celestialArchonWings => SocialRewardRarity.ancient,
        SocialRewardType.mythicDaevaChest => SocialRewardRarity.fabled,
        SocialRewardType.abyssCrystal => SocialRewardRarity.heroic,
        SocialRewardType.ancientEnchantmentStone => SocialRewardRarity.rare,
        SocialRewardType.factionHonorInsignia => SocialRewardRarity.heroic,
      };

  /// Creates a unified [RewardShaderConfig] initialized with this reward type's parameters.
  RewardShaderConfig toShaderConfig({
    required Size size,
    required double progress,
    double? time,
    SocialRewardRarity? rarity,
    double glowIntensity = 1.0,
    double speedMultiplier = 1.0,
  }) {
    return RewardShaderConfig(
      size: size,
      progress: progress,
      time: time,
      type: this,
      rarity: rarity ?? defaultRarity,
      glowIntensity: glowIntensity,
      speedMultiplier: speedMultiplier,
    );
  }
}

/// Rarity tier classification for social progression rewards.
enum SocialRewardRarity {
  common,
  uncommon,
  rare,
  heroic,
  fabled,
  mythic,
  ancient;

  String get label => name.toUpperCase();

  Color get color => switch (this) {
        SocialRewardRarity.common => SocialThemeTokens.rarityCommon,
        SocialRewardRarity.uncommon => SocialThemeTokens.rarityUncommon,
        SocialRewardRarity.rare => SocialThemeTokens.rarityRare,
        SocialRewardRarity.heroic => SocialThemeTokens.rarityHeroic,
        SocialRewardRarity.fabled => SocialThemeTokens.rarityFabled,
        SocialRewardRarity.mythic => SocialThemeTokens.rarityMythic,
        SocialRewardRarity.ancient => SocialThemeTokens.rarityAncient,
      };

  List<Color> get auraColors => switch (this) {
        SocialRewardRarity.common => const [Color(0xFF757575), Color(0xFF424242)],
        SocialRewardRarity.uncommon => const [Color(0xFF81C784), Color(0xFF2E7D32)],
        SocialRewardRarity.rare => const [Color(0xFF64B5F6), Color(0xFF1565C0)],
        SocialRewardRarity.heroic => const [Color(0xFFBA68C8), Color(0xFF6A1B9A)],
        SocialRewardRarity.fabled => const [Color(0xFFFFB74D), Color(0xFFE65100)],
        SocialRewardRarity.mythic => const [Color(0xFFFF5252), Color(0xFFB71C1C)],
        SocialRewardRarity.ancient => const [Color(0xFF18FFFF), Color(0xFF00B0FF), Color(0xFFFFD700)],
      };

  /// Zero-based tier integer index (0..6).
  int get tierIndex => index;

  /// Normalized tier progress [0.0 .. 1.0] across all 7 rarity tiers.
  double get tierProgress => index / (SocialRewardRarity.values.length - 1);

  /// Bloom glow scalar multiplier for GPU shader aura passes.
  double get glowMultiplier => switch (this) {
        SocialRewardRarity.common => 0.5,
        SocialRewardRarity.uncommon => 0.7,
        SocialRewardRarity.rare => 0.9,
        SocialRewardRarity.heroic => 1.1,
        SocialRewardRarity.fabled => 1.35,
        SocialRewardRarity.mythic => 1.6,
        SocialRewardRarity.ancient => 2.0,
      };

  /// Oscillation frequency speed multiplier for breathing & pulse animations.
  double get pulseSpeed => switch (this) {
        SocialRewardRarity.common => 0.8,
        SocialRewardRarity.uncommon => 1.0,
        SocialRewardRarity.rare => 1.15,
        SocialRewardRarity.heroic => 1.35,
        SocialRewardRarity.fabled => 1.5,
        SocialRewardRarity.mythic => 1.8,
        SocialRewardRarity.ancient => 2.2,
      };

  /// Recommended particle count for ambient GPU sparkles & orbiting motes.
  int get particleCount => switch (this) {
        SocialRewardRarity.common => 4,
        SocialRewardRarity.uncommon => 6,
        SocialRewardRarity.rare => 8,
        SocialRewardRarity.heroic => 12,
        SocialRewardRarity.fabled => 16,
        SocialRewardRarity.mythic => 20,
        SocialRewardRarity.ancient => 24,
      };
}

/// Model and uniform packing representation for Flutter/Impeller reward shaders.
///
/// Encapsulates all 24 uniform floats required by runtime fragment effects:
/// - 0..1:   uResolution (vec2)
/// - 2:      uTime (float)
/// - 3:      uProgress (float)
/// - 4:      uRewardType (float, 0..4)
/// - 5:      uRarityTier (float, 0.0..1.0)
/// - 6:      uGlowIntensity (float)
/// - 7:      uPulseSpeed (float)
/// - 8..11:  uPrimaryColor (vec4 in linear RGB)
/// - 12..15: uAccentColor (vec4 in linear RGB)
/// - 16..19: uRarityColor (vec4 in linear RGB)
/// - 20..23: uSecondaryColor (vec4 in linear RGB)
@immutable
class RewardShaderConfig {
  const RewardShaderConfig({
    required this.size,
    required this.progress,
    this.time,
    this.type = SocialRewardType.celestialArchonWings,
    this.rarity = SocialRewardRarity.ancient,
    this.overridePrimaryColor,
    this.overrideAccentColor,
    this.overrideSecondaryColor,
    this.overrideRarityColor,
    this.glowIntensity = 1.0,
    this.speedMultiplier = 1.0,
  });

  /// Total float uniform count in GLSL declaration sequence.
  static const int kUniformFloatCount = 24;

  final Size size;
  final double progress;
  final double? time;
  final SocialRewardType type;
  final SocialRewardRarity rarity;
  final Color? overridePrimaryColor;
  final Color? overrideAccentColor;
  final Color? overrideSecondaryColor;
  final Color? overrideRarityColor;
  final double glowIntensity;
  final double speedMultiplier;

  Color get primaryColor => overridePrimaryColor ?? type.primaryColor;
  Color get accentColor => overrideAccentColor ?? type.accentGlow;
  Color get secondaryColor => overrideSecondaryColor ?? type.secondaryColor;
  Color get rarityColor => overrideRarityColor ?? rarity.color;

  double get activeTime => time ?? (progress * 4.0);
  double get effectiveGlow => glowIntensity * rarity.glowMultiplier;
  double get effectiveSpeed => speedMultiplier * rarity.pulseSpeed;

  /// Converts an sRGB color component [0.0 .. 1.0] to linear RGB space.
  static double sRgbToLinear(double c) {
    return (c <= 0.04045)
        ? (c / 12.92)
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Converts a Flutter [Color] into 4 linear RGBA floats [r, g, b, a].
  static (double, double, double, double) colorToLinearRgba(Color color) {
    return (
      sRgbToLinear(color.r),
      sRgbToLinear(color.g),
      sRgbToLinear(color.b),
      color.a,
    );
  }

  /// Packs all 24 uniform floats into a contiguous Float32List buffer.
  Float32List packUniforms() {
    final Float32List buffer = Float32List(kUniformFloatCount);

    // 0..1: uResolution (vec2)
    buffer[0] = size.width;
    buffer[1] = size.height;

    // 2: uTime (float)
    buffer[2] = activeTime;

    // 3: uProgress (float)
    buffer[3] = progress;

    // 4: uRewardType (float)
    buffer[4] = type.index.toDouble();

    // 5: uRarityTier (float)
    buffer[5] = rarity.tierProgress;

    // 6: uGlowIntensity (float)
    buffer[6] = effectiveGlow;

    // 7: uPulseSpeed (float)
    buffer[7] = effectiveSpeed;

    // 8..11: uPrimaryColor (vec4 in linear RGB)
    final (double pr, double pg, double pb, double pa) = colorToLinearRgba(primaryColor);
    buffer[8] = pr;
    buffer[9] = pg;
    buffer[10] = pb;
    buffer[11] = pa;

    // 12..15: uAccentColor (vec4 in linear RGB)
    final (double ar, double ag, double ab, double aa) = colorToLinearRgba(accentColor);
    buffer[12] = ar;
    buffer[13] = ag;
    buffer[14] = ab;
    buffer[15] = aa;

    // 16..19: uRarityColor (vec4 in linear RGB)
    final (double rr, double rg, double rb, double ra) = colorToLinearRgba(rarityColor);
    buffer[16] = rr;
    buffer[17] = rg;
    buffer[18] = rb;
    buffer[19] = ra;

    // 20..23: uSecondaryColor (vec4 in linear RGB)
    final (double sr, double sg, double sb, double sa) = colorToLinearRgba(secondaryColor);
    buffer[20] = sr;
    buffer[21] = sg;
    buffer[22] = sb;
    buffer[23] = sa;

    return buffer;
  }

  /// Directly binds all 24 uniform floats into a compiled Flutter [ui.FragmentShader].
  void writeToShader(ui.FragmentShader shader) {
    final Float32List buffer = packUniforms();
    for (int i = 0; i < kUniformFloatCount; i++) {
      shader.setFloat(i, buffer[i]);
    }
  }

  RewardShaderConfig copyWith({
    Size? size,
    double? progress,
    double? time,
    SocialRewardType? type,
    SocialRewardRarity? rarity,
    Color? overridePrimaryColor,
    Color? overrideAccentColor,
    Color? overrideSecondaryColor,
    Color? overrideRarityColor,
    double? glowIntensity,
    double? speedMultiplier,
  }) {
    return RewardShaderConfig(
      size: size ?? this.size,
      progress: progress ?? this.progress,
      time: time ?? this.time,
      type: type ?? this.type,
      rarity: rarity ?? this.rarity,
      overridePrimaryColor: overridePrimaryColor ?? this.overridePrimaryColor,
      overrideAccentColor: overrideAccentColor ?? this.overrideAccentColor,
      overrideSecondaryColor: overrideSecondaryColor ?? this.overrideSecondaryColor,
      overrideRarityColor: overrideRarityColor ?? this.overrideRarityColor,
      glowIntensity: glowIntensity ?? this.glowIntensity,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
    );
  }
}

