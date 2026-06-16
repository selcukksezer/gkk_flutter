import 'package:flutter/material.dart';

import 'dungeon_cave_palettes.dart';

/// Per-dungeon hero card theme — colors pulled from cave art.
class CaveCardTheme {
  const CaveCardTheme({
    required this.surface,
    required this.surfaceDeep,
    required this.panel,
    required this.textPrimary,
    required this.textMuted,
    required this.accent,
    required this.accentDeep,
    required this.accentGlow,
    required this.secondary,
    required this.energy,
    required this.gold,
    required this.loot,
    required this.threatEasy,
    required this.threatMedium,
    required this.threatHard,
    required this.threatDeadly,
    required this.powerOk,
    required this.powerFail,
    required this.assetPath,
    required this.artBackground,
    required this.gradientColors,
    required this.gradientStops,
    required this.featherColors,
    required this.featherStops,
  });

  final Color surface;
  final Color surfaceDeep;
  final Color panel;
  final Color textPrimary;
  final Color textMuted;
  final Color accent;
  final Color accentDeep;
  final Color accentGlow;
  final Color secondary;
  final Color energy;
  final Color gold;
  final Color loot;
  final Color threatEasy;
  final Color threatMedium;
  final Color threatHard;
  final Color threatDeadly;
  final Color powerOk;
  final Color powerFail;
  final String assetPath;
  final Color artBackground;
  final List<Color> gradientColors;
  final List<double> gradientStops;
  final List<Color> featherColors;
  final List<double> featherStops;

  static const List<double> _kGradientStops = <double>[
    0,
    0.05,
    0.14,
    0.28,
    0.44,
    0.62,
  ];

  static const List<double> _kFeatherStops = <double>[
    0,
    0.04,
    0.14,
    0.28,
    0.44,
    0.62,
    0.82,
    1,
  ];

  /// Dungeon #1 — `dungeon1.png` cyber palette.
  static const CaveCardTheme cyberCave = CaveCardTheme(
    surface: Color(0xFF080B12),
    surfaceDeep: Color(0xFF080B12),
    panel: Color(0xFF2A3042),
    textPrimary: Color(0xFFE8EEF7),
    textMuted: Color(0xFF8E9CAE),
    accent: Color(0xFF00B4FF),
    accentDeep: Color(0xFF0090CC),
    accentGlow: Color(0xFF00FFFF),
    secondary: Color(0xFF8E9CAE),
    energy: Color(0xFF00B4FF),
    gold: Color(0xFFFFB800),
    loot: Color(0xFF8A2BE2),
    threatEasy: Color(0xFF00FF66),
    threatMedium: Color(0xFFFFD700),
    threatHard: Color(0xFFFF6B35),
    threatDeadly: Color(0xFFE52E2E),
    powerOk: Color(0xFF00FF66),
    powerFail: Color(0xFFE52E2E),
    assetPath: 'assets/dungeon/dungeon1.png',
    artBackground: Color(0xFF000000),
    gradientStops: <double>[0, 0.05, 0.14, 0.28, 0.44, 0.62],
    gradientColors: <Color>[
      Color(0x00000000),
      Color(0x00000000),
      Color(0x28080B12),
      Color(0x70080B12),
      Color(0xB3080B12),
      Color(0xE8080B12),
    ],
    featherStops: <double>[0, 0.04, 0.14, 0.28, 0.44, 0.62, 0.82, 1],
    featherColors: <Color>[
      Color(0x00000000),
      Color(0x0A000000),
      Color(0x22000000),
      Color(0x48000000),
      Color(0x78000000),
      Color(0xAA000000),
      Color(0xD5000000),
      Color(0xFFFFFFFF),
    ],
  );

  /// Dungeon #2 — `dungeon2.jpeg` tree portal palette.
  static const CaveCardTheme treePortal = CaveCardTheme(
    surface: Color(0xFF0A191E),
    surfaceDeep: Color(0xFF001F24),
    panel: Color(0xFF1B2520),
    textPrimary: Color(0xFFF5E6D3),
    textMuted: Color(0xFF9AAA9E),
    accent: Color(0xFFFF8C00),
    accentDeep: Color(0xFFE06A00),
    accentGlow: Color(0xFFFFB347),
    secondary: Color(0xFF606C38),
    energy: Color(0xFF7CB342),
    gold: Color(0xFFFFD700),
    loot: Color(0xFF8B6914),
    threatEasy: Color(0xFF7CB342),
    threatMedium: Color(0xFFFFB347),
    threatHard: Color(0xFFFF8C00),
    threatDeadly: Color(0xFFCC4A1A),
    powerOk: Color(0xFF606C38),
    powerFail: Color(0xFFCC4A1A),
    assetPath: 'assets/dungeon/dungeon2.jpeg',
    artBackground: Color(0xFF001F24),
    gradientStops: <double>[0, 0.05, 0.14, 0.28, 0.44, 0.62],
    gradientColors: <Color>[
      Color(0x00001F24),
      Color(0x00001F24),
      Color(0x280A191E),
      Color(0x700A191E),
      Color(0xB3001F24),
      Color(0xE8001F24),
    ],
    featherStops: <double>[0, 0.04, 0.14, 0.28, 0.44, 0.62, 0.82, 1],
    featherColors: <Color>[
      Color(0x00001F24),
      Color(0x0A001F24),
      Color(0x22001F24),
      Color(0x48001F24),
      Color(0x78001F24),
      Color(0xAA001F24),
      Color(0xD5001F24),
      Color(0xFFFFFFFF),
    ],
  );

  /// Dungeon #3 — `dungeon3.jpeg` crystal arcane gateway palette.
  static const CaveCardTheme crystalGateway = CaveCardTheme(
    surface: Color(0xFF0A1628),
    surfaceDeep: Color(0xFF060D18),
    panel: Color(0xFF1A3050),
    textPrimary: Color(0xFFE8F4FF),
    textMuted: Color(0xFF6B8FAE),
    accent: Color(0xFF00E5FF),
    accentDeep: Color(0xFF00A8CC),
    accentGlow: Color(0xFF7DF9FF),
    secondary: Color(0xFFD4AF37),
    energy: Color(0xFF00B4D8),
    gold: Color(0xFFD4AF37),
    loot: Color(0xFF4A6FA5),
    threatEasy: Color(0xFF4DD0E1),
    threatMedium: Color(0xFFD4AF37),
    threatHard: Color(0xFFFF8C42),
    threatDeadly: Color(0xFFE63946),
    powerOk: Color(0xFF00E5FF),
    powerFail: Color(0xFFE63946),
    assetPath: 'assets/dungeon/dungeon3.jpeg',
    artBackground: Color(0xFF060D18),
    gradientStops: <double>[0, 0.05, 0.14, 0.28, 0.44, 0.62],
    gradientColors: <Color>[
      Color(0x00060D18),
      Color(0x00060D18),
      Color(0x280A1628),
      Color(0x700A1628),
      Color(0xB3060D18),
      Color(0xE8060D18),
    ],
    featherStops: <double>[0, 0.04, 0.14, 0.28, 0.44, 0.62, 0.82, 1],
    featherColors: <Color>[
      Color(0x00060D18),
      Color(0x0A060D18),
      Color(0x22060D18),
      Color(0x48060D18),
      Color(0x78060D18),
      Color(0xAA060D18),
      Color(0xD5060D18),
      Color(0xFFFFFFFF),
    ],
  );

  /// Dungeon #4 — `dungeon4.jpeg` fungal forest vortex palette.
  static const CaveCardTheme fungalVortex = CaveCardTheme(
    surface: Color(0xFF1A2820),
    surfaceDeep: Color(0xFF0F1A14),
    panel: Color(0xFF243028),
    textPrimary: Color(0xFFF0E6F5),
    textMuted: Color(0xFF8A9E8C),
    accent: Color(0xFFE040FB),
    accentDeep: Color(0xFFAB47BC),
    accentGlow: Color(0xFFFF6EC7),
    secondary: Color(0xFF4A7C59),
    energy: Color(0xFF7CB342),
    gold: Color(0xFFFFB300),
    loot: Color(0xFF9C27B0),
    threatEasy: Color(0xFF7CB342),
    threatMedium: Color(0xFFFF6EC7),
    threatHard: Color(0xFFE040FB),
    threatDeadly: Color(0xFFC62828),
    powerOk: Color(0xFF4A7C59),
    powerFail: Color(0xFFC62828),
    assetPath: 'assets/dungeon/dungeon4.jpeg',
    artBackground: Color(0xFF0F1A14),
    gradientStops: <double>[0, 0.05, 0.14, 0.28, 0.44, 0.62],
    gradientColors: <Color>[
      Color(0x000F1A14),
      Color(0x000F1A14),
      Color(0x281A2820),
      Color(0x701A2820),
      Color(0xB30F1A14),
      Color(0xE80F1A14),
    ],
    featherStops: <double>[0, 0.04, 0.14, 0.28, 0.44, 0.62, 0.82, 1],
    featherColors: <Color>[
      Color(0x000F1A14),
      Color(0x0A0F1A14),
      Color(0x220F1A14),
      Color(0x480F1A14),
      Color(0x780F1A14),
      Color(0xAA0F1A14),
      Color(0xD50F1A14),
      Color(0xFFFFFFFF),
    ],
  );

  /// Dungeon #5 — `dungeon5.jpeg` iron forge vault palette.
  static const CaveCardTheme ironForge = CaveCardTheme(
    surface: Color(0xFF2A2A32),
    surfaceDeep: Color(0xFF1A1A22),
    panel: Color(0xFF3D3D48),
    textPrimary: Color(0xFFF5F0E8),
    textMuted: Color(0xFF9A9AAA),
    accent: Color(0xFFFF6B00),
    accentDeep: Color(0xFFCC5500),
    accentGlow: Color(0xFFFFAA33),
    secondary: Color(0xFFC9A227),
    energy: Color(0xFFFFB300),
    gold: Color(0xFFD4AF37),
    loot: Color(0xFFB87333),
    threatEasy: Color(0xFF7CB342),
    threatMedium: Color(0xFFFFB300),
    threatHard: Color(0xFFFF6B00),
    threatDeadly: Color(0xFFE52E2E),
    powerOk: Color(0xFFC9A227),
    powerFail: Color(0xFFE52E2E),
    assetPath: 'assets/dungeon/dungeon5.jpeg',
    artBackground: Color(0xFF1A1A22),
    gradientStops: <double>[0, 0.05, 0.14, 0.28, 0.44, 0.62],
    gradientColors: <Color>[
      Color(0x001A1A22),
      Color(0x001A1A22),
      Color(0x282A2A32),
      Color(0x702A2A32),
      Color(0xB31A1A22),
      Color(0xE81A1A22),
    ],
    featherStops: <double>[0, 0.04, 0.14, 0.28, 0.44, 0.62, 0.82, 1],
    featherColors: <Color>[
      Color(0x001A1A22),
      Color(0x0A1A1A22),
      Color(0x221A1A22),
      Color(0x481A1A22),
      Color(0x781A1A22),
      Color(0xAA1A1A22),
      Color(0xD51A1A22),
      Color(0xFFFFFFFF),
    ],
  );

  /// Dungeon #6 — `dungeon6.jpeg` infernal horn gate palette.
  static const CaveCardTheme infernalGate = CaveCardTheme(
    surface: Color(0xFF1A0A0A),
    surfaceDeep: Color(0xFF0D0505),
    panel: Color(0xFF2A1515),
    textPrimary: Color(0xFFFFE8E0),
    textMuted: Color(0xFF9A6B6B),
    accent: Color(0xFFFF3300),
    accentDeep: Color(0xFFCC2200),
    accentGlow: Color(0xFFFF6633),
    secondary: Color(0xFF4A2020),
    energy: Color(0xFFFF6B35),
    gold: Color(0xFFFFB800),
    loot: Color(0xFF8B2500),
    threatEasy: Color(0xFFFF8C42),
    threatMedium: Color(0xFFFFB800),
    threatHard: Color(0xFFFF3300),
    threatDeadly: Color(0xFFB71C1C),
    powerOk: Color(0xFFFF6633),
    powerFail: Color(0xFFB71C1C),
    assetPath: 'assets/dungeon/dungeon6.jpeg',
    artBackground: Color(0xFF0D0505),
    gradientStops: <double>[0, 0.05, 0.14, 0.28, 0.44, 0.62],
    gradientColors: <Color>[
      Color(0x000D0505),
      Color(0x000D0505),
      Color(0x281A0A0A),
      Color(0x701A0A0A),
      Color(0xB30D0505),
      Color(0xE80D0505),
    ],
    featherStops: <double>[0, 0.04, 0.14, 0.28, 0.44, 0.62, 0.82, 1],
    featherColors: <Color>[
      Color(0x000D0505),
      Color(0x0A0D0505),
      Color(0x220D0505),
      Color(0x480D0505),
      Color(0x780D0505),
      Color(0xAA0D0505),
      Color(0xD50D0505),
      Color(0xFFFFFFFF),
    ],
  );

  /// Dungeon #7 — `dungeon7.jpeg` celestial sanctum palette.
  static const CaveCardTheme celestialSanctum = CaveCardTheme(
    surface: Color(0xFF1A2238),
    surfaceDeep: Color(0xFF121A2E),
    panel: Color(0xFF2A3550),
    textPrimary: Color(0xFFFFF8F0),
    textMuted: Color(0xFF9AABCC),
    accent: Color(0xFF64B5F6),
    accentDeep: Color(0xFF42A5F5),
    accentGlow: Color(0xFFB3E5FC),
    secondary: Color(0xFFD4AF37),
    energy: Color(0xFF81D4FA),
    gold: Color(0xFFFFD54F),
    loot: Color(0xFF7986CB),
    threatEasy: Color(0xFF81C784),
    threatMedium: Color(0xFFFFD54F),
    threatHard: Color(0xFF64B5F6),
    threatDeadly: Color(0xFFE53935),
    powerOk: Color(0xFF64B5F6),
    powerFail: Color(0xFFE53935),
    assetPath: 'assets/dungeon/dungeon7.jpeg',
    artBackground: Color(0xFF121A2E),
    gradientStops: <double>[0, 0.05, 0.14, 0.28, 0.44, 0.62],
    gradientColors: <Color>[
      Color(0x00121A2E),
      Color(0x00121A2E),
      Color(0x281A2238),
      Color(0x701A2238),
      Color(0xB3121A2E),
      Color(0xE8121A2E),
    ],
    featherStops: <double>[0, 0.04, 0.14, 0.28, 0.44, 0.62, 0.82, 1],
    featherColors: <Color>[
      Color(0x00121A2E),
      Color(0x0A121A2E),
      Color(0x22121A2E),
      Color(0x48121A2E),
      Color(0x78121A2E),
      Color(0xAA121A2E),
      Color(0xD5121A2E),
      Color(0xFFFFFFFF),
    ],
  );

  static List<Color> _gradientColors(Color deep, Color surface) => <Color>[
        deep.withValues(alpha: 0),
        deep.withValues(alpha: 0),
        surface.withValues(alpha: 0.16),
        surface.withValues(alpha: 0.44),
        deep.withValues(alpha: 0.70),
        deep.withValues(alpha: 0.91),
      ];

  static List<Color> _featherColors(Color bg) => <Color>[
        bg.withValues(alpha: 0),
        bg.withValues(alpha: 0.04),
        bg.withValues(alpha: 0.13),
        bg.withValues(alpha: 0.28),
        bg.withValues(alpha: 0.47),
        bg.withValues(alpha: 0.67),
        bg.withValues(alpha: 0.84),
        const Color(0xFFFFFFFF),
      ];

  static CaveCardTheme fromArtPalette(int number, DungeonArtPalette palette) {
    return CaveCardTheme(
      surface: palette.surface,
      surfaceDeep: palette.surfaceDeep,
      panel: palette.panel,
      textPrimary: const Color(0xFFFFFFFF),
      textMuted: const Color(0xFFFFFFFF),
      accent: palette.accent,
      accentDeep: palette.accentDeep,
      accentGlow: palette.accentGlow,
      secondary: palette.secondary,
      energy: palette.accent,
      gold: const Color(0xFFFFD54F),
      loot: palette.secondary,
      threatEasy: palette.secondary,
      threatMedium: palette.accentGlow,
      threatHard: palette.accent,
      threatDeadly: const Color(0xFFE53935),
      powerOk: palette.secondary,
      powerFail: const Color(0xFFE53935),
      assetPath: 'assets/dungeon/dungeon$number.${palette.ext}',
      artBackground: palette.surfaceDeep,
      gradientStops: _kGradientStops,
      gradientColors: _gradientColors(palette.surfaceDeep, palette.surface),
      featherStops: _kFeatherStops,
      featherColors: _featherColors(palette.surfaceDeep),
    );
  }

  static CaveCardTheme? forDungeonNumber(int number) {
    return switch (number) {
      1 => cyberCave,
      2 => treePortal,
      3 => crystalGateway,
      4 => fungalVortex,
      5 => ironForge,
      6 => infernalGate,
      7 => celestialSanctum,
      _ => kDungeonPalettes[number] != null
          ? fromArtPalette(number, kDungeonPalettes[number]!)
          : null,
    };
  }

  Color threatForSuccess(int percent) {
    if (percent >= 80) return threatEasy;
    if (percent >= 55) return threatMedium;
    if (percent >= 30) return threatHard;
    return threatDeadly;
  }
}

/// Carved/inset text — layered offset, no TextStyle shadows.
class DungeonInsetText extends StatelessWidget {
  const DungeonInsetText(
    this.text, {
    super.key,
    this.style,
    this.color,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.depthOffset = const Offset(0, 1.5),
  });

  final String text;
  final TextStyle? style;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final Offset depthOffset;

  @override
  Widget build(BuildContext context) {
    final Color faceColor = color ?? const Color(0xFFE8EEF7);
    final TextStyle base = (style ?? const TextStyle()).copyWith(
      shadows: null,
      color: faceColor,
    );
    final TextStyle depth = base.copyWith(
      color: Colors.black.withValues(alpha: 0.72),
    );
    final TextStyle face = base.copyWith(
      color: faceColor.withValues(alpha: 0.9),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Transform.translate(
          offset: depthOffset,
          child: Text(
            text,
            style: depth,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
          ),
        ),
        Text(
          text,
          style: face,
          maxLines: maxLines,
          overflow: overflow,
          textAlign: textAlign,
        ),
      ],
    );
  }
}

/// Plain style helper — shadow-free for icons/labels inside inset chips.
abstract final class CaveTextStyle {
  static TextStyle title({
    Color color = const Color(0xFFE8EEF7),
    double size = 16,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1.1,
      );

  static TextStyle body({
    Color color = const Color(0xFF8E9CAE),
    double size = 12,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
        height: 1.3,
      );

  static TextStyle label({
    Color color = const Color(0xFF8E9CAE),
    double size = 9,
  }) =>
      TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: 0.7,
      );
}

/// Full-card gradient — transparent on image side, opaque on text side.
class CaveCardLeftGradient extends StatelessWidget {
  const CaveCardLeftGradient({super.key, required this.theme});

  final CaveCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          stops: theme.gradientStops,
          colors: theme.gradientColors,
        ),
      ),
    );
  }
}

/// Soft left-edge feather — alpha ramp matches gradient transparent edge.
class CaveArtWithFeatherEdge extends StatelessWidget {
  const CaveArtWithFeatherEdge({
    super.key,
    required this.size,
    required this.theme,
  });

  final double size;
  final CaveCardTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ShaderMask(
        shaderCallback: (Rect bounds) {
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            stops: theme.featherStops,
            colors: theme.featherColors,
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: Image.asset(
          theme.assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
