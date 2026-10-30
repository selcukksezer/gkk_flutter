import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gkk_flutter/theme/theme.dart';

void main() {
  group('Obsidian-Glass & Gold Runes Tokens Verification', () {
    test('Obsidian foundations match 2027 Aion 2 palette specifications', () {
      expect(ObsidianGlassTokens.obsidianVoid, equals(const Color(0xFF07090E)));
      expect(ObsidianGlassTokens.obsidianDeep, equals(const Color(0xFF090D15)));
      expect(ObsidianGlassTokens.obsidianSurface, equals(const Color(0xFF0F141F)));
      expect(ObsidianGlassTokens.obsidianCard, equals(const Color(0xFF141B2A)));
      expect(ObsidianGlassTokens.obsidianElevated, equals(const Color(0xFF1B2438)));
      expect(ObsidianGlassTokens.obsidianPanel, equals(const Color(0xE6090E17)));

      // Glass specular highlight and depth shadows
      expect(ObsidianGlassTokens.obsidianGlassTop, equals(const Color(0x4D1B2438)));
      expect(ObsidianGlassTokens.obsidianGlassBottom, equals(const Color(0x2B07090E)));
      expect(ObsidianGlassTokens.glassSpecular, equals(const Color(0x1FFFFFFF)));
    });

    test('Gold Rune & Elemental Rune tokens verify color luminosity', () {
      expect(ObsidianGlassTokens.goldRune, equals(const Color(0xFFFFD700)));
      expect(ObsidianGlassTokens.goldRuneLight, equals(const Color(0xFFFFF0A0)));
      expect(ObsidianGlassTokens.goldRuneDim, equals(const Color(0xFFB8860B)));
      expect(ObsidianGlassTokens.goldRuneBorder, equals(const Color(0x66FFD700)));
      expect(ObsidianGlassTokens.goldRuneGlow, equals(const Color(0x4DFFD700)));
      expect(ObsidianGlassTokens.goldRuneGlowFaint, equals(const Color(0x1AFFD700)));

      // Elemental Runes
      expect(ObsidianGlassTokens.crimsonRune, equals(const Color(0xFFFF1744)));
      expect(ObsidianGlassTokens.crimsonRuneGlow, equals(const Color(0x4DFF1744)));
      expect(ObsidianGlassTokens.cyanRune, equals(const Color(0xFF00E5FF)));
      expect(ObsidianGlassTokens.cyanRuneGlow, equals(const Color(0x4D00E5FF)));
      expect(ObsidianGlassTokens.toxicRune, equals(const Color(0xFF00FF66)));
    });

    test('Blur Sigmas strictly respect hardware tier constraints', () {
      expect(ObsidianGlassTokens.blurEco, equals(0.0), reason: 'Eco tier disables blur for 0 fill-rate overhead');
      expect(ObsidianGlassTokens.blurLow, equals(4.0));
      expect(ObsidianGlassTokens.blurMid, equals(8.0));
      expect(ObsidianGlassTokens.blurHigh, equals(12.0));
      expect(ObsidianGlassTokens.blurUltra, equals(16.0), reason: 'Ultra tier provides maximum frosted luxury');
    });

    test('ObsidianGlassDecoration helper builds valid decoration with shadow and border', () {
      final decoration = ObsidianGlassTokens.glassDecoration(
        borderRadius: 16.0,
        borderColor: ObsidianGlassTokens.goldRuneBorder,
        showGlow: true,
        glowColor: ObsidianGlassTokens.goldRune,
      );

      expect(decoration.borderRadius, equals(BorderRadius.circular(16.0)));
      expect(decoration.gradient, equals(ObsidianGlassTokens.obsidianGlassGradient));
      expect(decoration.border, isNotNull);
      expect(decoration.boxShadow, isNotEmpty);
      expect(decoration.boxShadow!.length, greaterThanOrEqualTo(2));
    });

    test('AppColors contains canonical consolidated obsidian and gold rune constants', () {
      expect(AppColors.obsidianVoid, equals(ObsidianGlassTokens.obsidianVoid));
      expect(AppColors.obsidianDeep, equals(ObsidianGlassTokens.obsidianDeep));
      expect(AppColors.obsidianSurface, equals(ObsidianGlassTokens.obsidianSurface));
      expect(AppColors.obsidianCard, equals(ObsidianGlassTokens.obsidianCard));
      expect(AppColors.obsidianElevated, equals(ObsidianGlassTokens.obsidianElevated));
      expect(AppColors.runeGold, equals(ObsidianGlassTokens.goldRune));
      expect(AppColors.runeGoldLight, equals(ObsidianGlassTokens.goldRuneLight));
      expect(AppColors.runeGoldDim, equals(ObsidianGlassTokens.goldRuneDim));
      expect(AppColors.runeGoldGlow, equals(ObsidianGlassTokens.goldRuneGlow));
      expect(AppColors.runeGoldBorder, equals(ObsidianGlassTokens.goldRuneBorder));
      expect(AppColors.runeCrimson, equals(ObsidianGlassTokens.crimsonRune));
      expect(AppColors.runeCyan, equals(ObsidianGlassTokens.cyanRune));
    });
  });

  group('ObsidianGlassTheme ThemeExtension Tests', () {
    test('Default dark instance has correct defaults and registered in AppTheme.dark', () {
      const theme = ObsidianGlassTheme.dark;
      expect(theme.voidBackground, equals(ObsidianGlassTokens.obsidianVoid));
      expect(theme.deepBackground, equals(ObsidianGlassTokens.obsidianDeep));
      expect(theme.surface, equals(ObsidianGlassTokens.obsidianSurface));
      expect(theme.cardBackground, equals(ObsidianGlassTokens.obsidianCard));
      expect(theme.runeGold, equals(ObsidianGlassTokens.goldRune));
      expect(theme.blurSigma, equals(ObsidianGlassTokens.blurMid));

      final ThemeData darkTheme = AppTheme.dark;
      final ObsidianGlassTheme? registeredExtension =
          darkTheme.extension<ObsidianGlassTheme>();
      expect(registeredExtension, isNotNull);
      expect(registeredExtension!.voidBackground, equals(ObsidianGlassTokens.obsidianVoid));
      expect(registeredExtension.runeGold, equals(ObsidianGlassTokens.goldRune));
    });

    test('copyWith properly modifies individual tokens while preserving others', () {
      const theme = ObsidianGlassTheme.dark;
      final modified = theme.copyWith(
        runeGold: const Color(0xFFE5A93C),
        blurSigma: 14.0,
      );

      expect(modified.runeGold, equals(const Color(0xFFE5A93C)));
      expect(modified.blurSigma, equals(14.0));
      expect(modified.voidBackground, equals(theme.voidBackground));
      expect(modified.cardBackground, equals(theme.cardBackground));
    });

    test('lerp cleanly interpolates color tokens and blur radius', () {
      const start = ObsidianGlassTheme.dark;
      final end = start.copyWith(
        voidBackground: const Color(0xFF000000),
        blurSigma: 0.0,
      );

      final lerped = start.lerp(end, 0.5);
      expect(lerped.blurSigma, closeTo(4.0, 0.01));
    });
  });
}
