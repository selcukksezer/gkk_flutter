import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Class crest descriptor and theme data for 2027 Aion 2 Mobile characters.
class FriendClassThemeData {
  const FriendClassThemeData({
    required this.name,
    required this.elementName,
    required this.primaryColor,
    required this.secondaryColor,
    required this.glowColor,
    required this.icon,
    required this.metallicGradient,
    required this.backgroundGradient,
  });

  final String name;
  final String elementName;
  final Color primaryColor;
  final Color secondaryColor;
  final Color glowColor;
  final IconData icon;
  final LinearGradient metallicGradient;
  final LinearGradient backgroundGradient;
}

/// Class crest descriptor and badge builder for Aion 2 Mobile characters.
class FriendClassCrest {
  // Pre-compiled V3 AAA Cyber-Fantasy Theme Definitions
  static const FriendClassThemeData _warriorTheme = FriendClassThemeData(
    name: 'Savaşçı',
    elementName: 'Ateş',
    primaryColor: Color(0xFFEF4444), // Crimson Flame
    secondaryColor: Color(0xFFFFA000), // Molten Amber
    glowColor: Color(0xFFFF3333),
    icon: Icons.shield_rounded,
    metallicGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFFFFE082),
        Color(0xFFEF4444),
        Color(0xFFFF8A65),
        Color(0xFFB71C1C),
        Color(0xFFFFD54F),
      ],
      stops: <double>[0.0, 0.28, 0.55, 0.82, 1.0],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFF2E0E0E),
        Color(0xFF160608),
      ],
    ),
  );

  static const FriendClassThemeData _mageTheme = FriendClassThemeData(
    name: 'Büyücü',
    elementName: 'Arkana',
    primaryColor: Color(0xFFA855F7), // Arcane Violet
    secondaryColor: Color(0xFFE879F9), // Astral Fuchsia
    glowColor: Color(0xFF9333EA),
    icon: Icons.auto_awesome_rounded,
    metallicGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFFF3E8FF),
        Color(0xFFA855F7),
        Color(0xFFC084FC),
        Color(0xFF581C87),
        Color(0xFFE9D5FF),
      ],
      stops: <double>[0.0, 0.28, 0.55, 0.82, 1.0],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFF220C33),
        Color(0xFF0F0519),
      ],
    ),
  );

  static const FriendClassThemeData _archerTheme = FriendClassThemeData(
    name: 'Okçu',
    elementName: 'Rüzgar',
    primaryColor: Color(0xFF06B6D4), // Cyan Arrow / Gale
    secondaryColor: Color(0xFF38BDF8), // Aether Sky
    glowColor: Color(0xFF00E5FF),
    icon: Icons.track_changes_rounded,
    metallicGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFFE0F2FE),
        Color(0xFF06B6D4),
        Color(0xFF67E8F9),
        Color(0xFF0E7490),
        Color(0xFFCCFBF1),
      ],
      stops: <double>[0.0, 0.28, 0.55, 0.82, 1.0],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFF05232E),
        Color(0xFF031118),
      ],
    ),
  );

  static const FriendClassThemeData _assassinTheme = FriendClassThemeData(
    name: 'Gölge',
    elementName: 'Karanlık',
    primaryColor: Color(0xFF6366F1), // Shadow Indigo
    secondaryColor: Color(0xFF818CF8), // Phantom Lavender
    glowColor: Color(0xFF4F46E5),
    icon: Icons.visibility_off_rounded,
    metallicGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFFE0E7FF),
        Color(0xFF6366F1),
        Color(0xFFA5B4FC),
        Color(0xFF312E81),
        Color(0xFFC7D2FE),
      ],
      stops: <double>[0.0, 0.28, 0.55, 0.82, 1.0],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFF141133),
        Color(0xFF08071A),
      ],
    ),
  );

  static const FriendClassThemeData _clericTheme = FriendClassThemeData(
    name: 'Şifacı',
    elementName: 'Güneş',
    primaryColor: Color(0xFFF59E0B), // Celestial Amber
    secondaryColor: Color(0xFFFFD54F), // Solar Gold
    glowColor: Color(0xFFFFB300),
    icon: Icons.health_and_safety_rounded,
    metallicGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFFFFFBEB),
        Color(0xFFFFD700),
        Color(0xFFF59E0B),
        Color(0xFFB45309),
        Color(0xFFFEF3C7),
      ],
      stops: <double>[0.0, 0.28, 0.55, 0.82, 1.0],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFF291F09),
        Color(0xFF140E03),
      ],
    ),
  );

  static const FriendClassThemeData _alchemistTheme = FriendClassThemeData(
    name: 'Simyacı',
    elementName: 'Zehir',
    primaryColor: Color(0xFF10B981), // Emerald Toxic
    secondaryColor: Color(0xFF34D399), // Bio Jade
    glowColor: Color(0xFF059669),
    icon: Icons.science_rounded,
    metallicGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFFECFDF5),
        Color(0xFF10B981),
        Color(0xFF6EE7B7),
        Color(0xFF065F46),
        Color(0xFFA7F3D0),
      ],
      stops: <double>[0.0, 0.28, 0.55, 0.82, 1.0],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFF072418),
        Color(0xFF03120C),
      ],
    ),
  );

  static const FriendClassThemeData _bardTheme = FriendClassThemeData(
    name: 'Ozan',
    elementName: 'Armoni',
    primaryColor: Color(0xFFEC4899), // Harmonic Rose
    secondaryColor: Color(0xFFF472B6), // Prismatic Pink
    glowColor: Color(0xFFDB2777),
    icon: Icons.music_note_rounded,
    metallicGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFFFDF2F8),
        Color(0xFFEC4899),
        Color(0xFFF9A8D4),
        Color(0xFF831843),
        Color(0xFFFCE7F3),
      ],
      stops: <double>[0.0, 0.28, 0.55, 0.82, 1.0],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFF2C0C1E),
        Color(0xFF16040E),
      ],
    ),
  );

  static const FriendClassThemeData _defaultTheme = FriendClassThemeData(
    name: 'Daeva',
    elementName: 'Eter',
    primaryColor: Color(0xFF38BDF8), // Astral Sky
    secondaryColor: Color(0xFF7DD3FC), // Aether Cyan
    glowColor: Color(0xFF0284C7),
    icon: Icons.military_tech_rounded,
    metallicGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFFF0F9FF),
        Color(0xFF38BDF8),
        Color(0xFFBAE6FD),
        Color(0xFF0369A1),
        Color(0xFFE0F2FE),
      ],
      stops: <double>[0.0, 0.28, 0.55, 0.82, 1.0],
    ),
    backgroundGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color(0xFF0B1D2F),
        Color(0xFF050E18),
      ],
    ),
  );

  /// Resolves full theme descriptor for a character class string.
  static FriendClassThemeData getTheme(String? characterClass) {
    final String cls = (characterClass ?? '').toLowerCase();
    if (cls.contains('savaş') ||
        cls.contains('warrior') ||
        cls.contains('gladiator') ||
        cls.contains('templar') ||
        cls.contains('tank')) {
      return _warriorTheme;
    }
    if (cls.contains('büyü') ||
        cls.contains('sorcerer') ||
        cls.contains('mage') ||
        cls.contains('arcane') ||
        cls.contains('spiritmaster') ||
        cls.contains('elementalist')) {
      return _mageTheme;
    }
    if (cls.contains('ok') ||
        cls.contains('ranger') ||
        cls.contains('archer') ||
        cls.contains('sniper') ||
        cls.contains('avcı')) {
      return _archerTheme;
    }
    if (cls.contains('gölge') ||
        cls.contains('shadow') ||
        cls.contains('assassin') ||
        cls.contains('rogue') ||
        cls.contains('suikast')) {
      return _assassinTheme;
    }
    if (cls.contains('şifa') ||
        cls.contains('cleric') ||
        cls.contains('priest') ||
        cls.contains('healer') ||
        cls.contains('chanter') ||
        cls.contains('rahip')) {
      return _clericTheme;
    }
    if (cls.contains('simya') ||
        cls.contains('alchemist') ||
        cls.contains('engineer') ||
        cls.contains('gunner')) {
      return _alchemistTheme;
    }
    if (cls.contains('ozan') ||
        cls.contains('bard') ||
        cls.contains('artist') ||
        cls.contains('songweaver')) {
      return _bardTheme;
    }
    return _defaultTheme;
  }

  static IconData getIcon(String? characterClass) {
    return getTheme(characterClass).icon;
  }

  static Color getColor(String? characterClass) {
    return getTheme(characterClass).primaryColor;
  }

  static Color getGlowColor(String? characterClass) {
    return getTheme(characterClass).glowColor;
  }

  static LinearGradient getMetallicGradient(String? characterClass) {
    return getTheme(characterClass).metallicGradient;
  }

  static LinearGradient getBackgroundGradient(String? characterClass) {
    return getTheme(characterClass).backgroundGradient;
  }

  static String getElementName(String? characterClass) {
    return getTheme(characterClass).elementName;
  }

  /// Builds a heraldic shield crest preview for profiles and sheets.
  static Widget heraldic({
    Key? key,
    required String? className,
    double size = 40.0,
    bool showAura = true,
    bool showBorderGleam = true,
  }) {
    return FriendClassHeraldicCrest(
      key: key,
      className: className,
      size: size,
      showAura: showAura,
      showBorderGleam: showBorderGleam,
    );
  }

  static String formatCp(int power) {
    if (power >= 1000000) {
      return '${(power / 1000000).toStringAsFixed(1)}M';
    }
    if (power >= 10000) {
      return '${(power / 1000).toStringAsFixed(1)}k';
    }
    return power.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

/// Glassmorphism Class Crest Pill Badge with metallic boundary sheen and elemental aura.
class ClassCrestBadge extends StatelessWidget {
  const ClassCrestBadge({
    super.key,
    required this.className,
    this.compact = false,
    this.showAura = true,
    this.showElementalDot = false,
  });

  final String className;
  final bool compact;
  final bool showAura;
  final bool showElementalDot;

  @override
  Widget build(BuildContext context) {
    final FriendClassThemeData theme = FriendClassCrest.getTheme(className);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 7 : 9),
        gradient: theme.metallicGradient,
        boxShadow: showAura
            ? <BoxShadow>[
                BoxShadow(
                  color: theme.glowColor.withValues(alpha: compact ? 0.28 : 0.38),
                  blurRadius: compact ? 6 : 10,
                  spreadRadius: compact ? -1 : 0,
                  offset: const Offset(0, 1),
                ),
                BoxShadow(
                  color: theme.glowColor.withValues(alpha: 0.12),
                  blurRadius: compact ? 12 : 18,
                  spreadRadius: compact ? 0 : 1,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(1.0), // Specular metallic hairline boundary
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8.5,
          vertical: compact ? 2.5 : 3.5,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 6 : 8),
          gradient: theme.backgroundGradient,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Elemental Rune / Icon with luminous aura glow
            Icon(
              theme.icon,
              size: compact ? 11 : 13,
              color: theme.primaryColor,
              shadows: <Shadow>[
                Shadow(
                  color: theme.glowColor.withValues(alpha: 0.9),
                  blurRadius: compact ? 4 : 7,
                ),
              ],
            ),
            const SizedBox(width: 4.5),
            // Class Name with specular typography
            Text(
              className,
              style: TextStyle(
                color: Color.lerp(theme.primaryColor, Colors.white, 0.22),
                fontSize: compact ? 10 : 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.35,
                shadows: <Shadow>[
                  Shadow(
                    color: theme.glowColor.withValues(alpha: 0.6),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
            if (showElementalDot) ...<Widget>[
              const SizedBox(width: 4),
              Container(
                width: compact ? 3.5 : 4.5,
                height: compact ? 3.5 : 4.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.secondaryColor,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: theme.secondaryColor,
                      blurRadius: 3,
                      spreadRadius: 0.5,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Aion 2 Mobile Combat Power (CP) glowing badge with auric gold metallic sheen.
class CombatPowerBadge extends StatelessWidget {
  const CombatPowerBadge({
    super.key,
    required this.power,
    this.compact = false,
  });

  final int power;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Dynamic prestige grading based on CP tiers
    final bool isMythic = power >= 1000000;
    final bool isFabled = power >= 500000;

    final LinearGradient borderGradient = isMythic
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFFF9C4),
              Color(0xFFFFD700),
              Color(0xFFFF4081),
              Color(0xFF00E5FF),
              Color(0xFFFFD700),
            ],
          )
        : isFabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFFFFDE7),
                  Color(0xFFFFD700),
                  Color(0xFFF59E0B),
                  Color(0xFFB45309),
                  Color(0xFFFFE082),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFFFFECB3),
                  Color(0xFFF5C842),
                  Color(0xFFB45309),
                  Color(0xFFF59E0B),
                ],
              );

    const Color glowColor = Color(0xFFF59E0B);
    const Color boltColor = Color(0xFFFFD54F);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 6 : 7),
        gradient: borderGradient,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: glowColor.withValues(alpha: isMythic ? 0.35 : 0.22),
            blurRadius: isMythic ? 10 : 6,
            spreadRadius: isMythic ? 0.5 : -0.5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(0.9), // Gold foil metallic border
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5.5 : 7.5,
          vertical: compact ? 2.0 : 2.8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(compact ? 5.1 : 6.1),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF261D0C),
              Color(0xFF140D04),
            ],
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.bolt_rounded,
              size: compact ? 11 : 13,
              color: boltColor,
              shadows: const <Shadow>[
                Shadow(
                  color: Color(0xFFFFD700),
                  blurRadius: 5,
                ),
              ],
            ),
            const SizedBox(width: 2),
            Text(
              'CP',
              style: TextStyle(
                color: const Color(0xFFFBBF24).withValues(alpha: 0.9),
                fontSize: compact ? 8.5 : 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              FriendClassCrest.formatCp(power),
              style: TextStyle(
                color: const Color(0xFFFFFBEB),
                fontSize: compact ? 10 : 11.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.35,
                shadows: const <Shadow>[
                  Shadow(
                    color: Color(0x66F59E0B),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Location & Area Badge with cyber-fantasy radar beacon and glassmorphism.
class LocationBadge extends StatelessWidget {
  const LocationBadge({
    super.key,
    required this.location,
    this.isOnline = true,
    this.showBackground = false,
  });

  final String location;
  final bool isOnline;
  final bool showBackground;

  @override
  Widget build(BuildContext context) {
    final Color beaconColor = isOnline ? const Color(0xFF38BDF8) : const Color(0xFF64748B);
    final Color textColor = isOnline ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final Widget badgeRow = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(
          isOnline ? Icons.location_on_outlined : Icons.schedule_rounded,
          size: 12,
          color: beaconColor,
          shadows: isOnline
              ? <Shadow>[
                  Shadow(
                    color: beaconColor.withValues(alpha: 0.75),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        const SizedBox(width: 3.5),
        Flexible(
          child: Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );

    if (!showBackground) {
      return badgeRow;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isOnline
              ? beaconColor.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: badgeRow,
    );
  }
}

/// AAA Cyber-Fantasy Heraldic Shield Crest with metallic bevels and elemental aura.
class FriendClassHeraldicCrest extends StatelessWidget {
  const FriendClassHeraldicCrest({
    super.key,
    required this.className,
    this.size = 40.0,
    this.showAura = true,
    this.showBorderGleam = true,
  });

  final String? className;
  final double size;
  final bool showAura;
  final bool showBorderGleam;

  @override
  Widget build(BuildContext context) {
    final FriendClassThemeData theme = FriendClassCrest.getTheme(className);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size(size, size),
            painter: _HeraldicShieldPainter(
              theme: theme,
              showAura: showAura,
              showBorderGleam: showBorderGleam,
            ),
          ),
          Icon(
            theme.icon,
            size: size * 0.44,
            color: Colors.white,
            shadows: <Shadow>[
              Shadow(
                color: theme.glowColor.withValues(alpha: 0.95),
                blurRadius: size * 0.15,
              ),
              Shadow(
                color: Colors.black.withValues(alpha: 0.8),
                offset: const Offset(0, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeraldicShieldPainter extends CustomPainter {
  _HeraldicShieldPainter({
    required this.theme,
    required this.showAura,
    required this.showBorderGleam,
  });

  final FriendClassThemeData theme;
  final bool showAura;
  final bool showBorderGleam;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Path shieldPath = _buildShieldPath(size);

    // 1. Ambient Elemental Aura
    if (showAura) {
      final Paint auraPaint = Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width * 0.5, size.height * 0.5),
          size.width * 0.65,
          <Color>[
            theme.glowColor.withValues(alpha: 0.45),
            theme.glowColor.withValues(alpha: 0.15),
            Colors.transparent,
          ],
          <double>[0.0, 0.55, 1.0],
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.5),
        size.width * 0.55,
        auraPaint,
      );
    }

    // 2. Abyssal Carbon Base Fill
    final Paint fillPaint = Paint()
      ..shader = theme.backgroundGradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(shieldPath, fillPaint);

    // 3. Inner Elemental Core Glow
    final Paint coreGlowPaint = Paint()
      ..shader = ui.Gradient.radial(
        Offset(size.width * 0.5, size.height * 0.4),
        size.width * 0.4,
        <Color>[
          theme.primaryColor.withValues(alpha: 0.35),
          Colors.transparent,
        ],
      );
    canvas.drawPath(shieldPath, coreGlowPaint);

    // 4. Directional Specular Reflection (PBR-like Fresnel Top Bevel)
    if (showBorderGleam) {
      final Paint sheenPaint = Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height * 0.6),
          <Color>[
            Colors.white.withValues(alpha: 0.28),
            Colors.white.withValues(alpha: 0.05),
            Colors.transparent,
          ],
          <double>[0.0, 0.35, 1.0],
        )
        ..style = PaintingStyle.fill;
      canvas.drawPath(shieldPath, sheenPaint);
    }

    // 5. Specular Metallic Rim Stroke
    final Paint metallicStrokePaint = Paint()
      ..shader = theme.metallicGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.4, size.width * 0.045);
    canvas.drawPath(shieldPath, metallicStrokePaint);

    // 6. Micro Inner Hairline Accent
    final Path innerPath = _buildInnerShieldPath(size);
    final Paint innerHairline = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(innerPath, innerHairline);
  }

  Path _buildShieldPath(Size size) {
    final double w = size.width;
    final double h = size.height;
    final Path path = Path();
    path.moveTo(w * 0.18, 0);
    path.lineTo(w * 0.82, 0);
    path.lineTo(w, h * 0.16);
    path.lineTo(w, h * 0.55);
    path.cubicTo(w, h * 0.82, w * 0.65, h * 0.96, w * 0.5, h);
    path.cubicTo(w * 0.35, h * 0.96, 0, h * 0.82, 0, h * 0.55);
    path.lineTo(0, h * 0.16);
    path.close();
    return path;
  }

  Path _buildInnerShieldPath(Size size) {
    final double w = size.width;
    final double h = size.height;
    final double inset = math.max(2.0, size.width * 0.07);
    final Path path = Path();
    path.moveTo(w * 0.22, inset);
    path.lineTo(w * 0.78, inset);
    path.lineTo(w - inset, h * 0.18);
    path.lineTo(w - inset, h * 0.54);
    path.cubicTo(w - inset, h * 0.78, w * 0.63, h * 0.92, w * 0.5, h - inset);
    path.cubicTo(w * 0.37, h * 0.92, inset, h * 0.78, inset, h * 0.54);
    path.lineTo(inset, h * 0.18);
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _HeraldicShieldPainter oldDelegate) {
    return oldDelegate.theme != theme ||
        oldDelegate.showAura != showAura ||
        oldDelegate.showBorderGleam != showBorderGleam;
  }
}

