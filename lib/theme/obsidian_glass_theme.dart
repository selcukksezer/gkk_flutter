import 'dart:ui';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';

/// 2027 Aion 2 Obsidian-Glass & Gold Runes Design System Tokens.
///
/// Centralizes all dark obsidian foundations, frosted glass blur sigmas,
/// luminous gold rune borders, ancient glyph accents, and responsive elevation tiers.
abstract final class ObsidianGlassTokens {
  // ── Obsidian Foundations ────────────────────────────────────────────────
  /// Pure obsidian void (deepest black-slate base)
  static const Color obsidianVoid = Color(0xFF07090E);

  /// Deep obsidian layer for page foundations
  static const Color obsidianDeep = Color(0xFF090D15);

  /// Standard obsidian surface for containers and bento modules
  static const Color obsidianSurface = Color(0xFF0F141F);

  /// Primary card background
  static const Color obsidianCard = Color(0xFF141B2A);

  /// Elevated card background for interactive hover/selected states
  static const Color obsidianElevated = Color(0xFF1B2438);

  /// Translucent obsidian backdrop panel (90% alpha)
  static const Color obsidianPanel = Color(0xE6090E17);

  // ── Glass Translucencies ────────────────────────────────────────────────
  /// Translucent upper specular highlight for frosted glass
  static const Color obsidianGlassTop = Color(0x4D1B2438);

  /// Translucent lower shadow for frosted glass depth
  static const Color obsidianGlassBottom = Color(0x2B07090E);

  /// Subtle inner specular shine
  static const Color glassSpecular = Color(0x1FFFFFFF);

  // ── Obsidian Borders ────────────────────────────────────────────────────
  /// Faint border for soft card separation
  static const Color obsidianBorderFaint = Color(0xFF121824);

  /// Standard border for obsidian surfaces
  static const Color obsidianBorder = Color(0xFF1C2538);

  /// Bright border for active or focused obsidian components
  static const Color obsidianBorderBright = Color(0xFF2C3B54);

  // ── Gold Runes & Inscriptions ───────────────────────────────────────────
  /// Radiant gold rune primary color
  static const Color goldRune = Color(0xFFFFD700);

  /// Luminous highlight gold
  static const Color goldRuneLight = Color(0xFFFFF0A0);

  /// Deep antique gold for inactive runes
  static const Color goldRuneDim = Color(0xFFB8860B);

  /// Border gold with 40% luminescence
  static const Color goldRuneBorder = Color(0x66FFD700);

  /// Soft gold rune glow halo (30% alpha)
  static const Color goldRuneGlow = Color(0x4DFFD700);

  /// Faint gold rune ambient glow (10% alpha)
  static const Color goldRuneGlowFaint = Color(0x1AFFD700);

  // ── Elemental & Status Runes ────────────────────────────────────────────
  /// Crimson warning and combat rune
  static const Color crimsonRune = Color(0xFFFF1744);
  static const Color crimsonRuneGlow = Color(0x4DFF1744);

  /// Celestial mana cyan rune
  static const Color cyanRune = Color(0xFF00E5FF);
  static const Color cyanRuneGlow = Color(0x4D00E5FF);

  /// Toxic / bio green rune
  static const Color toxicRune = Color(0xFF00FF66);
  static const Color toxicRuneGlow = Color(0x4D00FF66);

  // ── Frosted Blur Sigmas (Hardware-tier aligned) ──────────────────────────
  /// Eco tier: 0.0 (blur disabled to avoid GPU fill-rate hitching)
  static const double blurEco = 0.0;

  /// Low tier: 4.0
  static const double blurLow = 4.0;

  /// Mid tier: 8.0
  static const double blurMid = 8.0;

  /// High tier: 12.0
  static const double blurHigh = 12.0;

  /// Ultra tier: 16.0 (deep frosted glass)
  static const double blurUltra = 16.0;

  // ── AAA Gradients ───────────────────────────────────────────────────────
  /// Frosted obsidian glass diagonal gradient
  static const LinearGradient obsidianGlassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0x381B2438),
      Color(0x2407090E),
    ],
  );

  /// Solid obsidian card gradient
  static const LinearGradient obsidianCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xEA141B2A),
      Color(0xF5090D15),
    ],
  );

  /// Ancient gold rune metallic shine gradient
  static const LinearGradient goldRuneGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFF0A0),
      Color(0xFFFFD700),
      Color(0xFFB8860B),
    ],
    stops: <double>[0.0, 0.52, 1.0],
  );

  /// Crimson combat rune gradient
  static const LinearGradient crimsonRuneGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFF5252),
      Color(0xFFFF1744),
      Color(0xFFB71C1C),
    ],
  );

  /// Cyan mana rune gradient
  static const LinearGradient cyanRuneGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF18FFFF),
      Color(0xFF00E5FF),
      Color(0xFF0091EA),
    ],
  );

  // ── Box Shadows & Halos ─────────────────────────────────────────────────
  /// Luminous gold rune outer glow
  static const List<BoxShadow> goldRuneHalo = <BoxShadow>[
    BoxShadow(
      color: goldRuneGlow,
      blurRadius: 12,
      spreadRadius: 1,
    ),
  ];

  /// Deep obsidian glass elevation shadow
  static const List<BoxShadow> obsidianGlassShadow = <BoxShadow>[
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];

  /// Helper generating a complete obsidian glass [BoxDecoration].
  static BoxDecoration glassDecoration({
    double borderRadius = AppSpacing.radiusLg,
    Color? borderColor,
    Color? glowColor,
    bool showGlow = false,
  }) {
    final effectiveBorder = borderColor ?? obsidianBorder;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      gradient: obsidianGlassGradient,
      border: Border.all(
        color: effectiveBorder,
        width: 1.0,
      ),
      boxShadow: <BoxShadow>[
        ...obsidianGlassShadow,
        if (showGlow && glowColor != null)
          BoxShadow(
            color: glowColor.withValues(alpha: 0.35),
            blurRadius: 12,
            spreadRadius: 0,
          ),
      ],
    );
  }
}

/// Material 3 [ThemeExtension] exposing obsidian glass and rune tokens
/// through `Theme.of(context).extension<ObsidianGlassTheme>()`.
@immutable
class ObsidianGlassTheme extends ThemeExtension<ObsidianGlassTheme> {
  final Color voidBackground;
  final Color deepBackground;
  final Color surface;
  final Color cardBackground;
  final Color borderDefault;
  final Color borderBright;
  final Color runeGold;
  final Color runeGlow;
  final Color runeCrimson;
  final Color runeCyan;
  final double blurSigma;

  const ObsidianGlassTheme({
    this.voidBackground = ObsidianGlassTokens.obsidianVoid,
    this.deepBackground = ObsidianGlassTokens.obsidianDeep,
    this.surface = ObsidianGlassTokens.obsidianSurface,
    this.cardBackground = ObsidianGlassTokens.obsidianCard,
    this.borderDefault = ObsidianGlassTokens.obsidianBorder,
    this.borderBright = ObsidianGlassTokens.obsidianBorderBright,
    this.runeGold = ObsidianGlassTokens.goldRune,
    this.runeGlow = ObsidianGlassTokens.goldRuneGlow,
    this.runeCrimson = ObsidianGlassTokens.crimsonRune,
    this.runeCyan = ObsidianGlassTokens.cyanRune,
    this.blurSigma = ObsidianGlassTokens.blurMid,
  });

  /// Default dark theme instance for gkk_flutter.
  static const ObsidianGlassTheme dark = ObsidianGlassTheme();

  @override
  ObsidianGlassTheme copyWith({
    Color? voidBackground,
    Color? deepBackground,
    Color? surface,
    Color? cardBackground,
    Color? borderDefault,
    Color? borderBright,
    Color? runeGold,
    Color? runeGlow,
    Color? runeCrimson,
    Color? runeCyan,
    double? blurSigma,
  }) {
    return ObsidianGlassTheme(
      voidBackground: voidBackground ?? this.voidBackground,
      deepBackground: deepBackground ?? this.deepBackground,
      surface: surface ?? this.surface,
      cardBackground: cardBackground ?? this.cardBackground,
      borderDefault: borderDefault ?? this.borderDefault,
      borderBright: borderBright ?? this.borderBright,
      runeGold: runeGold ?? this.runeGold,
      runeGlow: runeGlow ?? this.runeGlow,
      runeCrimson: runeCrimson ?? this.runeCrimson,
      runeCyan: runeCyan ?? this.runeCyan,
      blurSigma: blurSigma ?? this.blurSigma,
    );
  }

  @override
  ObsidianGlassTheme lerp(ThemeExtension<ObsidianGlassTheme>? other, double t) {
    if (other is! ObsidianGlassTheme) {
      return this;
    }
    return ObsidianGlassTheme(
      voidBackground: Color.lerp(voidBackground, other.voidBackground, t) ?? voidBackground,
      deepBackground: Color.lerp(deepBackground, other.deepBackground, t) ?? deepBackground,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t) ?? cardBackground,
      borderDefault: Color.lerp(borderDefault, other.borderDefault, t) ?? borderDefault,
      borderBright: Color.lerp(borderBright, other.borderBright, t) ?? borderBright,
      runeGold: Color.lerp(runeGold, other.runeGold, t) ?? runeGold,
      runeGlow: Color.lerp(runeGlow, other.runeGlow, t) ?? runeGlow,
      runeCrimson: Color.lerp(runeCrimson, other.runeCrimson, t) ?? runeCrimson,
      runeCyan: Color.lerp(runeCyan, other.runeCyan, t) ?? runeCyan,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t) ?? blurSigma,
    );
  }
}
