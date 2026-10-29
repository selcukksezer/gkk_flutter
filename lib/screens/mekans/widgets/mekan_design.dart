import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../l10n/l10n.dart';
import '../../../theme/app_colors.dart';
import 'mekan_theme.dart';

/// Next-gen neon palette and design tokens for the Mekan ("Han") experience.
/// Scoped to mekan screens only; the rest of the app keeps [AppColors].
abstract final class MekanPalette {
  static const Color void_ = Color(0xFF080B12); // Carbon Void
  static const Color navy = Color(0xFF121826); // Space Navy
  static const Color surface = Color(0xFF161D2E);
  static const Color surfaceHi = Color(0xFF1E2740);
  static const Color obsidian = Color(0xFF2A3042); // Dark Obsidian
  static const Color titanium = Color(0xFF8E9CAE); // Muted Titanium

  static const Color aqua = Color(0xFF00B4FF); // Telegram Aqua
  static const Color gold = Color(0xFFFFB800); // Liquid Gold
  static const Color fuchsia = Color(0xFFE01E5A); // Cyber Fuchsia

  static const Color ruby = Color(0xFFE52E2E); // Mystic Ruby
  static const Color neon = Color(0xFF00FF66); // Toxic Neon
  static const Color amethyst = Color(0xFF8A2BE2); // Royal Amethyst
  static const Color coral = Color(0xFFFF6B35); // Coral Flare
  static const Color cyan = Color(0xFF00FFFF); // Abyss Cyan
  static const Color solar = Color(0xFFFFD700); // Warning Solar

  static const Color textHi = Color(0xFFF2F6FF);
  static const Color textMid = Color(0xFFA9B7D0);
  static const Color textLow = Color(0xFF5C6B86);

  // Glassmorphic design tokens
  static const Color glassHighlight = Color(0x28FFFFFF);
  static const Color glassBorder = Color(0x38FFFFFF);
  static const Color glassBorderSubtle = Color(0x18FFFFFF);
  static const Color glassSurface = Color(0xD9161D2E);
  static const Color glassSurfaceDeep = Color(0xEB0D121F);

  // Standard blur scale
  static const double blurSm = 8.0;
  static const double blurMd = 16.0;
  static const double blurLg = 24.0;

  // Corner radii scale
  static const double radiusSm = 10.0;
  static const double radiusMd = 14.0;
  static const double radiusLg = 18.0;
  static const double radiusXl = 24.0;
  static const double radiusPill = 999.0;

  // Gradients
  static const LinearGradient goldGrad = LinearGradient(
    colors: <Color>[Color(0xFFFFDF70), gold, Color(0xFFD67E00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient aquaGrad = LinearGradient(
    colors: <Color>[Color(0xFF38C8FF), aqua, Color(0xFF007ACC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient rubyGrad = LinearGradient(
    colors: <Color>[Color(0xFFFF5454), ruby, Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient neonGrad = LinearGradient(
    colors: <Color>[Color(0xFF69F0AE), neon, Color(0xFF00C853)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient amethystGrad = LinearGradient(
    colors: <Color>[Color(0xFFB388FF), amethyst, Color(0xFF6200EA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient glassSurfaceGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xEE1E2740),
      Color(0xF0121826),
      Color(0xF8080B12),
    ],
    stops: <double>[0.0, 0.45, 1.0],
  );

  static const LinearGradient specularHighlightGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0x30FFFFFF),
      Color(0x06FFFFFF),
      Colors.transparent,
    ],
    stops: <double>[0.0, 0.35, 1.0],
  );

  /// Generates a layered neon glow shadow list.
  static List<BoxShadow> glowShadow(Color accent, {double blur = 22, double spread = -2, double alpha = 0.25}) {
    return <BoxShadow>[
      BoxShadow(
        color: accent.withValues(alpha: alpha),
        blurRadius: blur,
        offset: const Offset(0, 6),
        spreadRadius: spread,
      ),
      BoxShadow(
        color: void_.withValues(alpha: 0.75),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ];
  }

  /// Ambient dark depth shadow for separation.
  static List<BoxShadow> ambientShadow({double blur = 14, Offset offset = const Offset(0, 5)}) {
    return <BoxShadow>[
      BoxShadow(
        color: void_.withValues(alpha: 0.65),
        blurRadius: blur,
        offset: offset,
      ),
    ];
  }

  /// Accent color for a mekan type key.
  static Color accent(String? typeKey) {
    switch (typeKey) {
      case 'bar':
        return aqua;
      case 'kahvehane':
        return gold;
      case 'dovus_kulubu':
        return ruby;
      case 'luks_lounge':
        return amethyst;
      case 'yeralti':
        return neon;
      default:
        return aqua;
    }
  }

  /// Canonical icon for a mekan type key.
  static IconData typeIcon(String? typeKey) {
    switch (typeKey) {
      case 'bar':
        return Icons.local_bar_rounded;
      case 'kahvehane':
        return Icons.coffee_rounded;
      case 'dovus_kulubu':
        return Icons.sports_mma_rounded;
      case 'luks_lounge':
        return Icons.diamond_rounded;
      case 'yeralti':
        return Icons.dark_mode_rounded;
      default:
        return Icons.storefront_rounded;
    }
  }
}

/// Centralized typographic tokens for the Mekan UI following glassmorphism conventions.
abstract final class MekanTypography {
  static const TextStyle displayLarge = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: MekanPalette.textHi,
    letterSpacing: -0.2,
  );

  static const TextStyle titleLarge = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w900,
    color: MekanPalette.textHi,
    letterSpacing: 0.35,
  );

  static const TextStyle titleMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    color: MekanPalette.textHi,
    letterSpacing: 0.8,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    color: MekanPalette.textHi,
    letterSpacing: 0.9,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: MekanPalette.textMid,
    letterSpacing: 0.2,
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: MekanPalette.textMid,
    height: 1.4,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    color: MekanPalette.textHi,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.5,
  );

  static const TextStyle pill = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w900,
    letterSpacing: 0.7,
  );

  static const TextStyle chip = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.3,
  );

  static const TextStyle statValue = TextStyle(
    fontSize: 15.5,
    fontWeight: FontWeight.w900,
    color: MekanPalette.textHi,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle statLabel = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: MekanPalette.textLow,
    letterSpacing: 0.3,
  );

  static const TextStyle priceSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w900,
    color: Color(0xFF241700),
    letterSpacing: 0.2,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );

  static const TextStyle priceRegular = TextStyle(
    fontSize: 14.5,
    fontWeight: FontWeight.w900,
    color: Color(0xFF241700),
    letterSpacing: 0.2,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}

/// Full-bleed animated backdrop: deep gradient + runic geometry + starmap + glow orbs.
class MekanBackdrop extends StatelessWidget {
  const MekanBackdrop({super.key, required this.child, this.accent = MekanPalette.aqua});

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[MekanPalette.void_, MekanPalette.navy, MekanPalette.void_],
          stops: <double>[0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: _BackdropPainter(accent: accent),
        child: child,
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.accent});
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Celestial nebula glow pools (Aion-2 dark fantasy mobile atmosphere)
    final Paint nebula1 = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          accent.withValues(alpha: 0.24),
          accent.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.14),
          radius: 260,
        ),
      );
    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.14), 260, nebula1);

    final Paint nebula2 = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          MekanPalette.fuchsia.withValues(alpha: 0.16),
          MekanPalette.amethyst.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.10, size.height * 0.60),
          radius: 280,
        ),
      );
    canvas.drawCircle(Offset(size.width * 0.10, size.height * 0.60), 280, nebula2);

    final Paint nebula3 = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          MekanPalette.cyan.withValues(alpha: 0.11),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.50, size.height * 0.90),
          radius: 220,
        ),
      );
    canvas.drawCircle(Offset(size.width * 0.50, size.height * 0.90), 220, nebula3);

    // 2. Arcane Runic Constellation Geometry
    final Paint runeLine = Paint()
      ..color = accent.withValues(alpha: 0.09)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final Paint runeCircle = Paint()
      ..color = accent.withValues(alpha: 0.07)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Runic Celestial Ring in upper-right
    final Offset runeCenter = Offset(size.width * 0.82, size.height * 0.16);
    canvas.drawCircle(runeCenter, 70, runeCircle);
    canvas.drawCircle(runeCenter, 95, runeCircle);
    canvas.drawCircle(
      runeCenter,
      130,
      Paint()
        ..color = accent.withValues(alpha: 0.04)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );

    // Crosshairs on runic ring
    canvas.drawLine(
      Offset(runeCenter.dx - 140, runeCenter.dy),
      Offset(runeCenter.dx + 140, runeCenter.dy),
      runeLine,
    );
    canvas.drawLine(
      Offset(runeCenter.dx, runeCenter.dy - 140),
      Offset(runeCenter.dx, runeCenter.dy + 140),
      runeLine,
    );

    // Lower arcane ring
    final Offset lowerRune = Offset(size.width * 0.18, size.height * 0.75);
    canvas.drawCircle(lowerRune, 85, runeCircle);
    canvas.drawCircle(
      lowerRune,
      120,
      Paint()
        ..color = MekanPalette.fuchsia.withValues(alpha: 0.045)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke,
    );

    // 3. Starmap grid with shimmering astral nodes
    final Paint dot = Paint()..color = Colors.white.withValues(alpha: 0.035);
    const double gap = 28;
    for (double y = 14; y < size.height; y += gap) {
      for (double x = 14; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 0.9, dot);
      }
    }

    // 4. Fixed ethereal constellation stars (Aion-2 motif)
    final List<Offset> starNodes = <Offset>[
      Offset(size.width * 0.22, size.height * 0.08),
      Offset(size.width * 0.35, size.height * 0.13),
      Offset(size.width * 0.48, size.height * 0.09),
      Offset(size.width * 0.72, size.height * 0.28),
      Offset(size.width * 0.65, size.height * 0.42),
      Offset(size.width * 0.82, size.height * 0.52),
      Offset(size.width * 0.28, size.height * 0.62),
      Offset(size.width * 0.15, size.height * 0.78),
      Offset(size.width * 0.42, size.height * 0.84),
      Offset(size.width * 0.78, size.height * 0.88),
    ];

    final Paint starPaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    final Paint starGlow = Paint()..color = accent.withValues(alpha: 0.35);

    for (int i = 0; i < starNodes.length; i++) {
      final Offset pos = starNodes[i];
      final double r = (i % 3 == 0) ? 2.2 : 1.5;
      canvas.drawCircle(pos, r * 2.5, starGlow);
      canvas.drawCircle(pos, r, starPaint);
      if (i > 0 && i < starNodes.length - 1 && i % 2 == 1) {
        canvas.drawLine(
          starNodes[i - 1],
          starNodes[i],
          Paint()
            ..color = accent.withValues(alpha: 0.07)
            ..strokeWidth = 0.8,
        );
      }
    }

    // 5. Cinematic Mobile Vignette Layers (top, bottom, and radial edges)
    // Ensures crisp WCAG 2.2 AA outdoor readability for headers and bottom controls
    final Paint topVignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.68),
          Colors.black.withValues(alpha: 0.25),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 130));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, 130), topVignette);

    final Paint bottomVignette = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[
          Colors.black.withValues(alpha: 0.78),
          Colors.black.withValues(alpha: 0.35),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, size.height - 160, size.width, 160));
    canvas.drawRect(Rect.fromLTWH(0, size.height - 160, size.width, 160), bottomVignette);

    final Paint sideVignette = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.95,
        colors: <Color>[
          Colors.transparent,
          Colors.black.withValues(alpha: 0.28),
          Colors.black.withValues(alpha: 0.55),
        ],
        stops: const <double>[0.65, 0.85, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sideVignette);
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) => oldDelegate.accent != accent;
}

/// Tactile scale and subtle opacity feedback on press for interactive surfaces.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.onTap, this.enabled = true});

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _down ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Frosted neon panel with outer unclipped glow, glassmorphic backdrop filter,
/// specular highlights, and luminous accent border.
class NeonPanel extends StatelessWidget {
  const NeonPanel({
    super.key,
    required this.child,
    this.accent = MekanPalette.aqua,
    this.padding = const EdgeInsets.all(16),
    this.glow = true,
    this.radius = 18,
    this.blur = MekanPalette.blurMd,
    this.borderWidth = 1.3,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final bool glow;
  final double radius;
  final double blur;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.24),
                  blurRadius: 26,
                  offset: const Offset(0, 8),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: MekanPalette.void_.withValues(alpha: 0.80),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : <BoxShadow>[
                BoxShadow(
                  color: MekanPalette.void_.withValues(alpha: 0.65),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  MekanPalette.surfaceHi.withValues(alpha: 0.88),
                  MekanPalette.navy.withValues(alpha: 0.90),
                  MekanPalette.void_.withValues(alpha: 0.96),
                ],
                stops: const <double>[0.0, 0.45, 1.0],
              ),
              borderRadius: br,
              border: Border.all(
                color: accent.withValues(alpha: 0.42),
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Reusable lightweight glassmorphic card container with subtle blur and luminous border.
class MekanGlassCard extends StatelessWidget {
  const MekanGlassCard({
    super.key,
    required this.child,
    this.accent = MekanPalette.aqua,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.glow = false,
    this.borderOpacity = 0.35,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool glow;
  final double borderOpacity;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: MekanPalette.void_.withValues(alpha: 0.70),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : <BoxShadow>[
                BoxShadow(
                  color: MekanPalette.void_.withValues(alpha: 0.60),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14.0, sigmaY: 14.0),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accent.withValues(alpha: 0.12),
                  MekanPalette.surfaceHi.withValues(alpha: 0.75),
                  MekanPalette.void_.withValues(alpha: 0.90),
                ],
                stops: const <double>[0.0, 0.45, 1.0],
              ),
              borderRadius: br,
              border: Border.all(
                color: accent.withValues(alpha: borderOpacity),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Luminous hairline divider with center-to-edge fade.
class MekanGlowDivider extends StatelessWidget {
  const MekanGlowDivider({
    super.key,
    this.accent = MekanPalette.aqua,
    this.height = 16,
  });

  final Color accent;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Center(
        child: Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Colors.transparent,
                accent.withValues(alpha: 0.50),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphic frosted chip with unclipped neon glow and high-contrast typography.
class GlowChip extends StatelessWidget {
  const GlowChip({
    super.key,
    required this.icon,
    required this.label,
    this.color = MekanPalette.titanium,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(999);
    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.20),
            blurRadius: 10,
            spreadRadius: -1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  color.withValues(alpha: 0.22),
                  color.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: br,
              border: Border.all(color: color.withValues(alpha: 0.50), width: 1.1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.3,
                    shadows: <Shadow>[
                      Shadow(color: color.withValues(alpha: 0.45), blurRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Section header with vertical glowing accent indicator and high-contrast typography.
class NeonSectionHeader extends StatelessWidget {
  const NeonSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.accent = MekanPalette.aqua,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                accent,
                accent.withValues(alpha: 0.65),
              ],
            ),
            borderRadius: BorderRadius.circular(4),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.65),
                blurRadius: 10,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: MekanPalette.textHi,
                  letterSpacing: 0.9,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 1),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: MekanPalette.textMid,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Squircle type badge with glowing frosted glass and neon aura.
class MekanTypeBadge extends StatelessWidget {
  const MekanTypeBadge({super.key, required this.typeKey, this.size = 52});

  final String? typeKey;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color accent = MekanPalette.accent(typeKey);
    final BorderRadius br = BorderRadius.circular(size * 0.30);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.38),
            blurRadius: 16,
            spreadRadius: -1,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.50),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  accent.withValues(alpha: 0.36),
                  MekanPalette.surface.withValues(alpha: 0.72),
                  accent.withValues(alpha: 0.10),
                ],
                stops: const <double>[0.0, 0.55, 1.0],
              ),
              borderRadius: br,
              border: Border.all(color: accent.withValues(alpha: 0.80), width: 1.4),
            ),
            child: Icon(
              MekanPalette.typeIcon(typeKey),
              color: accent,
              size: size * 0.48,
              shadows: <Shadow>[
                Shadow(color: accent.withValues(alpha: 0.85), blurRadius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live status indicator with glowing LED dot and frosted glass pill.
class MekanStatusPill extends StatelessWidget {
  const MekanStatusPill({super.key, required this.isOpen});
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final Color c = isOpen ? MekanPalette.neon : MekanPalette.ruby;
    final BorderRadius br = BorderRadius.circular(999);
    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: c.withValues(alpha: 0.28),
            blurRadius: 12,
            spreadRadius: -1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  c.withValues(alpha: 0.22),
                  c.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: br,
              border: Border.all(color: c.withValues(alpha: 0.70), width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(color: c.withValues(alpha: 0.95), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isOpen ? 'AÇIK' : 'KAPALI',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: c,
                    letterSpacing: 0.7,
                    shadows: <Shadow>[
                      Shadow(color: c.withValues(alpha: 0.6), blurRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Signature gold badge with specular highlight, rich gradient, and tabular digits.
class GoldPriceBadge extends StatelessWidget {
  const GoldPriceBadge({super.key, required this.amount, this.small = false, this.discounted = false});

  final int amount;
  final bool small;
  final bool discounted;

  @override
  Widget build(BuildContext context) {
    final Color shadowColor = discounted ? MekanPalette.neon : MekanPalette.gold;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 9 : 13, vertical: small ? 4.5 : 7.5),
      decoration: BoxDecoration(
        gradient: discounted
            ? const LinearGradient(
                colors: <Color>[Color(0xFF34D399), Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: <Color>[Color(0xFFFFDF70), MekanPalette.gold, Color(0xFFD67E00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.42),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.paid_rounded, size: small ? 13 : 16, color: const Color(0xFF322200)),
          const SizedBox(width: 4.5),
          Text(
            formatMekanGold(amount),
            style: TextStyle(
              fontSize: small ? 12 : 14.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF241700),
              letterSpacing: 0.2,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Glowing bento loot card for a sellable item, with rarity ring + price badge.
class LootStockCard extends StatelessWidget {
  const LootStockCard({
    super.key,
    required this.name,
    required this.itemId,
    required this.icon,
    required this.rarity,
    required this.quantity,
    required this.price,
    this.isHanOnly = false,
    this.contraband = false,
    this.discounted = false,
    this.onTap,
    this.trailing,
  });

  final String name;
  final String itemId;
  final String icon;
  final String rarity;
  final int quantity;
  final int price;
  final bool isHanOnly;
  final bool contraband;
  final bool discounted;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Color rare = AppColors.forRarity(rarity);
    final BorderRadius br = BorderRadius.circular(16);
    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: br,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: rare.withValues(alpha: 0.26),
              blurRadius: 18,
              offset: const Offset(0, 6),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: MekanPalette.void_.withValues(alpha: 0.70),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: br,
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    rare.withValues(alpha: 0.20),
                    MekanPalette.surfaceHi.withValues(alpha: 0.82),
                    MekanPalette.navy.withValues(alpha: 0.96),
                  ],
                  stops: const <double>[0.0, 0.40, 1.0],
                ),
                borderRadius: br,
                border: Border.all(color: rare.withValues(alpha: 0.58), width: 1.3),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      if (contraband)
                        GlowChip(icon: Icons.warning_amber_rounded, label: context.l10n.kacak, color: MekanPalette.neon)
                      else if (isHanOnly)
                        const GlowChip(icon: Icons.local_fire_department_rounded, label: 'HAN', color: MekanPalette.fuchsia)
                      else
                        GlowChip(icon: Icons.auto_awesome, label: rarity.toUpperCase(), color: rare),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: MekanPalette.void_.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
                        ),
                        child: Text(
                          'x$quantity',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: MekanPalette.textMid,
                            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(color: rare.withValues(alpha: 0.38), blurRadius: 20),
                          ],
                        ),
                        child: ItemIconView(iconValue: icon, itemId: itemId, size: 58, fallback: '🧪'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: MekanPalette.textHi,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.center,
                    child: GoldPriceBadge(amount: price, small: true, discounted: discounted),
                  ),
                  if (trailing != null) ...<Widget>[const SizedBox(height: 8), trailing!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary gold-gradient or frosted accent-outline call to action.
class NeonButton extends StatelessWidget {
  const NeonButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.accent = MekanPalette.gold,
    this.filled = true,
    this.busy = false,
    this.expand = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color accent;
  final bool filled;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null && !busy;
    final BorderRadius br = BorderRadius.circular(14);

    final Widget inner = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (busy)
          SizedBox(
            width: 17,
            height: 17,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: filled ? const Color(0xFF241700) : accent,
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: filled ? const Color(0xFF241700) : accent),
        if (!busy && icon != null) const SizedBox(width: 8),
        if (busy) const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: filled ? const Color(0xFF241700) : accent,
            shadows: filled
                ? null
                : <Shadow>[
                    Shadow(color: accent.withValues(alpha: 0.5), blurRadius: 6),
                  ],
          ),
        ),
      ],
    );

    final Widget buttonBody = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        gradient: filled
            ? LinearGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.98),
                  accent,
                  accent.withValues(alpha: 0.88),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : LinearGradient(
                colors: <Color>[
                  accent.withValues(alpha: 0.18),
                  MekanPalette.navy.withValues(alpha: 0.78),
                  MekanPalette.void_.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: br,
        border: Border.all(
          color: filled ? Colors.white.withValues(alpha: 0.40) : accent.withValues(alpha: 0.70),
          width: 1.3,
        ),
      ),
      child: Center(child: inner),
    );

    final Widget styledButton = Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: enabled
            ? <BoxShadow>[
                BoxShadow(
                  color: (filled ? accent : accent.withValues(alpha: 0.28)).withValues(alpha: 0.40),
                  blurRadius: 18,
                  offset: const Offset(0, 5),
                  spreadRadius: -1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: filled
          ? buttonBody
          : ClipRRect(
              borderRadius: br,
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
                child: buttonBody,
              ),
            ),
    );

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: PressableScale(
        onTap: enabled ? onPressed : null,
        child: styledButton,
      ),
    );
  }
}

/// Ruby/gold urgency banner with a live countdown (Party / Happy Hour / raid).
class HappyHourBanner extends StatelessWidget {
  const HappyHourBanner({
    super.key,
    required this.until,
    this.title = 'PARTİ CANLI',
    this.subtitle = 'Gece special — %20 menü indirimi + parti',
  });

  final DateTime until;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: MekanPalette.coral.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFFF8A00), MekanPalette.coral, MekanPalette.ruby],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: br,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            CountdownText(until: until, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Dynamic suspicion meter with tri-color warning levels and frosted track.
class SuspicionMeter extends StatelessWidget {
  const SuspicionMeter({super.key, required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    final double pct = (value / 100).clamp(0, 1).toDouble();
    final Color c = value > 60 ? MekanPalette.ruby : (value > 30 ? MekanPalette.solar : MekanPalette.neon);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(Icons.visibility_rounded, size: 14, color: c),
            const SizedBox(width: 6),
            const Text(
              'Polis Şüphesi',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MekanPalette.textMid,
                letterSpacing: 0.2,
              ),
            ),
            const Spacer(),
            Text(
              '$value/100',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: c,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: MekanPalette.obsidian,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 0.8),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: c.withValues(alpha: 0.20),
                blurRadius: 6,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: Colors.transparent,
              color: c,
            ),
          ),
        ),
      ],
    );
  }
}

/// Self-updating countdown that ticks every second until [until], using tabular figures.
class CountdownText extends StatefulWidget {
  const CountdownText({super.key, required this.until, this.color = MekanPalette.textHi, this.onDone});

  final DateTime until;
  final Color color;
  final VoidCallback? onDone;

  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (widget.until.isBefore(DateTime.now())) {
        _timer?.cancel();
        widget.onDone?.call();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    if (d.isNegative) return '00:00';
    final int h = d.inHours;
    final int m = d.inMinutes.remainder(60);
    final int s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}s ${m.toString().padLeft(2, '0')}d';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final Duration left = widget.until.difference(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.timer_rounded, size: 13, color: widget.color),
          const SizedBox(width: 4.5),
          Text(
            _fmt(left),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: widget.color,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Polished empty state with glowing circular pedestal and balanced typography.
class MekanEmpty extends StatelessWidget {
  const MekanEmpty({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.accent = MekanPalette.aqua,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[
                    accent.withValues(alpha: 0.22),
                    accent.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 42,
                color: accent,
                shadows: <Shadow>[
                  Shadow(color: accent.withValues(alpha: 0.7), blurRadius: 12),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: MekanPalette.textHi,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: MekanPalette.textMid,
                height: 1.45,
              ),
            ),
            if (action != null) ...<Widget>[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Small numeric stat block used in hero headers / dashboards with glassmorphism backing.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = MekanPalette.aqua,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = BorderRadius.circular(12);
    return Container(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  MekanPalette.surfaceHi.withValues(alpha: 0.65),
                  MekanPalette.void_.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: br,
              border: Border.all(color: color.withValues(alpha: 0.30), width: 1.1),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  icon,
                  size: 18,
                  color: color,
                  shadows: <Shadow>[
                    Shadow(color: color.withValues(alpha: 0.6), blurRadius: 8),
                  ],
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: MekanPalette.textHi,
                        fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: MekanPalette.textLow,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
