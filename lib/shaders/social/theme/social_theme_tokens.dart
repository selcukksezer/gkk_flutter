import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// 2027 Aion 2 Mobile Design System Tokens for Social & Progression Systems.
///
/// Features authentic celestial aether, iridescent chromatic sheens,
/// abyssal dark backgrounds, guild/faction prestige palettes,
/// IEC 61966-2-1 linear RGB conversion helpers, ITU-R BT.709 relative luminance
/// calculations, and Impeller-compliant shader uniform color packing.
abstract final class SocialThemeTokens {
  // --- Celestial & Aether Palettes ---
  static const Color celestialGold = Color(0xFFFFD700);
  static const Color celestialGoldLight = Color(0xFFFFF4B8);
  static const Color celestialGoldDark = Color(0xFFB8860B);
  static const Color celestialAmber = Color(0xFFFF9100);

  static const Color aetherCyan = Color(0xFF00E5FF);
  static const Color aetherCyanLight = Color(0xFF80F3FF);
  static const Color aetherCyanDark = Color(0xFF00838F);
  static const Color aetherBlue = Color(0xFF00B0FF);

  // --- Abyssal Dark & Cosmic Canvas ---
  static const Color abyssVoid = Color(0xFF050811);
  static const Color abyssDeep = Color(0xFF0A0F1F);
  static const Color abyssCard = Color(0xFF10192E);
  static const Color abyssCardSurface = Color(0xFF16223B);
  static const Color abyssCardHighlight = Color(0xFF1E2E4F);

  // --- Faction & Heraldic Tints ---
  // Elyos: Sacred Solar Celestial
  static const Color elyosGold = Color(0xFFFFD54F);
  static const Color elyosRadiance = Color(0xFFFFF9C4);
  static const Color elyosSky = Color(0xFF4FC3F7);

  // Asmodian: Shadow Astral Legion
  static const Color asmodianViolet = Color(0xFFAB47BC);
  static const Color asmodianCrimson = Color(0xFFE91E63);
  static const Color asmodianDeepShadow = Color(0xFF311B92);

  // Balaur: Dragonic Primal Fury
  static const Color balaurFlame = Color(0xFFFF3D00);
  static const Color balaurRuby = Color(0xFFD50000);
  static const Color balaurGold = Color(0xFFFFC107);

  // Daeva: Ascendant Divine Prismatic
  static const Color daevaPrismViolet = Color(0xFF7C4DFF);
  static const Color daevaPrismCyan = Color(0xFF18FFFF);
  static const Color daevaPrismWhite = Color(0xFFFFFFFF);

  // --- Rarity Tiers ---
  static const Color rarityCommon = Color(0xFF9E9E9E);
  static const Color rarityUncommon = Color(0xFF4CAF50);
  static const Color rarityRare = Color(0xFF2196F3);
  static const Color rarityHeroic = Color(0xFF9C27B0);
  static const Color rarityFabled = Color(0xFFFF9800);
  static const Color rarityMythic = Color(0xFFFF1744);
  static const Color rarityAncient = Color(0xFF00E5FF);

  // --- Iridescent & Holographic Gradient Stops ---
  static const List<Color> iridescentStops = <Color>[
    Color(0x00FFFFFF),
    Color(0x1800E5FF),
    Color(0x40FFFFFF),
    Color(0x28FFD700),
    Color(0x18FF4081),
    Color(0x00FFFFFF),
  ];

  // --- Celestial Wave Gradients ---
  static const LinearGradient celestialBannerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFF0A1128),
      Color(0xFF101F42),
      Color(0xFF0E1A38),
      Color(0xFF060B18),
    ],
  );

  static const LinearGradient goldBorderGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFECB3),
      Color(0xFFFFD700),
      Color(0xFFB8860B),
      Color(0xFFFFD700),
      Color(0xFFFFF9C4),
    ],
  );

  static const LinearGradient celestialGlowGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0x3300E5FF),
      Color(0x1A7C4DFF),
      Color(0x00000000),
    ],
  );

  // --- Shadows & Glows ---
  static List<BoxShadow> celestialGlow({
    Color color = aetherCyan,
    double blur = 16.0,
    double spread = 1.0,
  }) {
    return <BoxShadow>[
      BoxShadow(
        color: color.withValues(alpha: 0.35),
        blurRadius: blur,
        spreadRadius: spread,
      ),
      BoxShadow(
        color: color.withValues(alpha: 0.15),
        blurRadius: blur * 2,
        spreadRadius: spread * 1.5,
      ),
    ];
  }

  static List<BoxShadow> goldGlow({
    double blur = 18.0,
    double spread = 2.0,
  }) {
    return <BoxShadow>[
      BoxShadow(
        color: celestialGold.withValues(alpha: 0.4),
        blurRadius: blur,
        spreadRadius: spread,
      ),
      BoxShadow(
        color: celestialAmber.withValues(alpha: 0.2),
        blurRadius: blur * 2.2,
        spreadRadius: spread * 1.2,
      ),
    ];
  }

  // ===========================================================================
  // Linear RGB Color Space Conversion Helpers (IEC 61966-2-1 Standard)
  // Required for physically accurate lighting, tone mapping, and Impeller shaders.
  // ===========================================================================

  /// Converts a single non-linear sRGB channel [0.0 .. 1.0] to linear RGB space
  /// using the precise piecewise IEC 61966-2-1 transfer function.
  static double sRgbToLinear(double c) {
    final double clamped = c.clamp(0.0, 1.0);
    return (clamped <= 0.04045)
        ? (clamped / 12.92)
        : math.pow((clamped + 0.055) / 1.055, 2.4).toDouble();
  }

  /// Converts a single linear RGB channel [0.0 .. 1.0] to non-linear sRGB space
  /// using the inverse piecewise IEC 61966-2-1 transfer function.
  static double linearToSRgb(double c) {
    final double clamped = c.clamp(0.0, 1.0);
    return (clamped <= 0.0031308)
        ? (clamped * 12.92)
        : (1.055 * math.pow(clamped, 1.0 / 2.4).toDouble() - 0.055);
  }

  /// Fast power-law approximation of sRGB to linear conversion: `c^2.2`.
  static double sRgbToLinearFast(double c) {
    return math.pow(c.clamp(0.0, 1.0), 2.2).toDouble();
  }

  /// Fast power-law approximation of linear to sRGB conversion: `c^(1 / 2.2)`.
  static double linearToSRgbFast(double c) {
    return math.pow(c.clamp(0.0, 1.0), 1.0 / 2.2).toDouble();
  }

  /// Converts a [Color] into 3 linear RGB components `(r, g, b)` in range [0.0 .. 1.0].
  static (double, double, double) colorToLinearRgb(Color color) {
    return (
      sRgbToLinear(color.r),
      sRgbToLinear(color.g),
      sRgbToLinear(color.b),
    );
  }

  /// Converts a [Color] into 4 linear RGBA components `(r, g, b, a)` in range [0.0 .. 1.0].
  static (double, double, double, double) colorToLinearRgba(Color color) {
    return (
      sRgbToLinear(color.r),
      sRgbToLinear(color.g),
      sRgbToLinear(color.b),
      color.a,
    );
  }

  /// Reconstructs a Flutter [Color] from linear RGB components and optional alpha.
  static Color colorFromLinearRgb(
    double r,
    double g,
    double b, [
    double a = 1.0,
  ]) {
    final int red = (linearToSRgb(r) * 255.0).round().clamp(0, 255);
    final int green = (linearToSRgb(g) * 255.0).round().clamp(0, 255);
    final int blue = (linearToSRgb(b) * 255.0).round().clamp(0, 255);
    final int alpha = (a * 255.0).round().clamp(0, 255);
    return Color.fromARGB(alpha, red, green, blue);
  }

  // ===========================================================================
  // Luminance & Contrast Calculations (ITU-R BT.709 & WCAG 2.1 Standard)
  // ===========================================================================

  /// Computes the ITU-R BT.709 photometric relative luminance (Y) of a [Color]
  /// using linear RGB values. Returns value in [0.0 .. 1.0].
  static double relativeLuminance(Color color) {
    final (double r, double g, double b) = colorToLinearRgb(color);
    return (0.2126 * r + 0.7152 * g + 0.0722 * b).clamp(0.0, 1.0);
  }

  /// Computes the ITU-R BT.601 non-linear perceived luma (Y') using gamma-encoded sRGB values.
  static double perceivedLuma(Color color) {
    return (0.299 * color.r + 0.587 * color.g + 0.114 * color.b).clamp(0.0, 1.0);
  }

  /// Computes the WCAG 2.1 contrast ratio between two colors: `(L1 + 0.05) / (L2 + 0.05)`.
  /// Returns a ratio from 1.0 (identical) to 21.0 (pure black on pure white).
  static double contrastRatio(Color a, Color b) {
    final double l1 = relativeLuminance(a);
    final double l2 = relativeLuminance(b);
    final double lighter = math.max(l1, l2);
    final double darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Returns true if [color]'s relative luminance exceeds [threshold] (default 0.5).
  static bool isLight(Color color, {double threshold = 0.5}) {
    return relativeLuminance(color) > threshold;
  }

  /// Returns true if [color]'s relative luminance is less than or equal to [threshold] (default 0.5).
  static bool isDark(Color color, {double threshold = 0.5}) {
    return relativeLuminance(color) <= threshold;
  }

  // ===========================================================================
  // Shader Color Uniform Packing & Binding Helpers (Impeller RuntimeEffect)
  // ===========================================================================

  /// Packs a [Color] into a 3-element double list `[r, g, b]` for GLSL `vec3` uniforms.
  /// If [linear] is true (default), components are converted to linear RGB space.
  static List<double> toVec3(Color color, {bool linear = true}) {
    if (linear) {
      final (double r, double g, double b) = colorToLinearRgb(color);
      return <double>[r, g, b];
    }
    return <double>[color.r, color.g, color.b];
  }

  /// Packs a [Color] into a 4-element double list `[r, g, b, a]` for GLSL `vec4` uniforms.
  /// If [linear] is true (default), color components are converted to linear RGB space.
  static List<double> toVec4(Color color, {bool linear = true}) {
    if (linear) {
      final (double r, double g, double b, double a) = colorToLinearRgba(color);
      return <double>[r, g, b, a];
    }
    return <double>[color.r, color.g, color.b, color.a];
  }

  /// Writes 3 float values into [buffer] at [offset] for a GLSL `vec3` uniform.
  static void packVec3(
    Float32List buffer,
    int offset,
    Color color, {
    bool linear = true,
  }) {
    if (linear) {
      final (double r, double g, double b) = colorToLinearRgb(color);
      buffer[offset] = r;
      buffer[offset + 1] = g;
      buffer[offset + 2] = b;
    } else {
      buffer[offset] = color.r;
      buffer[offset + 1] = color.g;
      buffer[offset + 2] = color.b;
    }
  }

  /// Writes 4 float values into [buffer] at [offset] for a GLSL `vec4` uniform.
  static void packVec4(
    Float32List buffer,
    int offset,
    Color color, {
    bool linear = true,
  }) {
    if (linear) {
      final (double r, double g, double b, double a) = colorToLinearRgba(color);
      buffer[offset] = r;
      buffer[offset + 1] = g;
      buffer[offset + 2] = b;
      buffer[offset + 3] = a;
    } else {
      buffer[offset] = color.r;
      buffer[offset + 1] = color.g;
      buffer[offset + 2] = color.b;
      buffer[offset + 3] = color.a;
    }
  }

  /// Binds 3 float uniforms directly to a Flutter [ui.FragmentShader] starting at [startIndex]
  /// for a GLSL `vec3` uniform.
  static void setShaderVec3(
    ui.FragmentShader shader,
    int startIndex,
    Color color, {
    bool linear = true,
  }) {
    if (linear) {
      final (double r, double g, double b) = colorToLinearRgb(color);
      shader.setFloat(startIndex, r);
      shader.setFloat(startIndex + 1, g);
      shader.setFloat(startIndex + 2, b);
    } else {
      shader.setFloat(startIndex, color.r);
      shader.setFloat(startIndex + 1, color.g);
      shader.setFloat(startIndex + 2, color.b);
    }
  }

  /// Binds 4 float uniforms directly to a Flutter [ui.FragmentShader] starting at [startIndex]
  /// for a GLSL `vec4` uniform.
  static void setShaderVec4(
    ui.FragmentShader shader,
    int startIndex,
    Color color, {
    bool linear = true,
  }) {
    if (linear) {
      final (double r, double g, double b, double a) = colorToLinearRgba(color);
      shader.setFloat(startIndex, r);
      shader.setFloat(startIndex + 1, g);
      shader.setFloat(startIndex + 2, b);
      shader.setFloat(startIndex + 3, a);
    } else {
      shader.setFloat(startIndex, color.r);
      shader.setFloat(startIndex + 1, color.g);
      shader.setFloat(startIndex + 2, color.b);
      shader.setFloat(startIndex + 3, color.a);
    }
  }
}

