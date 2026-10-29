import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'guild_design.dart';

/// Guild visual prestige tier based on level and monument standing.
enum GuildPrestigeTier {
  bronze,
  silver,
  gold,
  celestial,
  eternal;

  static GuildPrestigeTier fromLevel(int level) {
    if (level >= 80) return GuildPrestigeTier.eternal;
    if (level >= 50) return GuildPrestigeTier.celestial;
    if (level >= 30) return GuildPrestigeTier.gold;
    if (level >= 15) return GuildPrestigeTier.silver;
    return GuildPrestigeTier.bronze;
  }

  Color get primaryAccent => switch (this) {
        GuildPrestigeTier.bronze => GuildPalette.coral,
        GuildPrestigeTier.silver => GuildPalette.titanium,
        GuildPrestigeTier.gold => GuildPalette.gold,
        GuildPrestigeTier.celestial => GuildPalette.iridescentCyan,
        GuildPrestigeTier.eternal => GuildPalette.iridescentRose,
      };

  Color get secondaryAccent => switch (this) {
        GuildPrestigeTier.bronze => const Color(0xFF8D4F23),
        GuildPrestigeTier.silver => const Color(0xFF64748B),
        GuildPrestigeTier.gold => const Color(0xFFB45309),
        GuildPrestigeTier.celestial => GuildPalette.iridescentViolet,
        GuildPrestigeTier.eternal => GuildPalette.gold,
      };

  Color get tertiaryAccent => switch (this) {
        GuildPrestigeTier.bronze => const Color(0xFFFFB380),
        GuildPrestigeTier.silver => const Color(0xFFF1F5F9),
        GuildPrestigeTier.gold => const Color(0xFFFFF176),
        GuildPrestigeTier.celestial => const Color(0xFFA7F3D0),
        GuildPrestigeTier.eternal => const Color(0xFFFF80DF),
      };

  LinearGradient get metallicGradient => switch (this) {
        GuildPrestigeTier.bronze => const LinearGradient(
            colors: <Color>[Color(0xFFFF8A65), Color(0xFFB35A22), Color(0xFF5D2800)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        GuildPrestigeTier.silver => const LinearGradient(
            colors: <Color>[Color(0xFFFFFFFF), Color(0xFF94A3B8), Color(0xFF334155)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        GuildPrestigeTier.gold => const LinearGradient(
            colors: <Color>[Color(0xFFFFF59D), Color(0xFFFFB300), Color(0xFF8D5300)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        GuildPrestigeTier.celestial => const LinearGradient(
            colors: <Color>[Color(0xFF80DEEA), Color(0xFF00E5FF), Color(0xFF7C4DFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        GuildPrestigeTier.eternal => const LinearGradient(
            colors: <Color>[Color(0xFFFF80AB), Color(0xFFFF1744), Color(0xFFFFD54F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
      };

  String get label => switch (this) {
        GuildPrestigeTier.bronze => 'BRONZ LEJYON',
        GuildPrestigeTier.silver => 'GÜMÜŞ MUHAFIZ',
        GuildPrestigeTier.gold => 'ALTIN HANEDAN',
        GuildPrestigeTier.celestial => 'GÖKSEL KADİM',
        GuildPrestigeTier.eternal => 'EBEDİ EFSANE',
      };

  String get runeGlyph => switch (this) {
        GuildPrestigeTier.bronze => '᚛',
        GuildPrestigeTier.silver => 'ᛏ',
        GuildPrestigeTier.gold => '◈',
        GuildPrestigeTier.celestial => '⟡',
        GuildPrestigeTier.eternal => '✦',
      };
}

/// 2027 Aion 2 Celestial Guild Emblem Painter with multi-layered sacred geometry,
/// PBR metallic bevels, breathing iridescent aura, rotating cosmic rune rings,
/// sculpted angelic wing crest, and faceted gemstone core.
class GuildCelestialEmblemPainter extends CustomPainter {
  const GuildCelestialEmblemPainter({
    required this.progress,
    required this.tier,
    this.monogram = '⚔️',
    this.glowOpacity = 0.8,
    this.showRuneRing = true,
  });

  final double progress; // 0.0 to 1.0 (looping animation)
  final GuildPrestigeTier tier;
  final String monogram;
  final double glowOpacity;
  final bool showRuneRing;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = math.min(cx, cy);
    if (r <= 0) return;

    final double pulse = 0.88 + 0.12 * math.sin(progress * 2 * math.pi);
    final double rot = progress * 2 * math.pi;

    final Color primary = tier.primaryAccent;
    final Color secondary = tier.secondaryAccent;
    final Color tertiary = tier.tertiaryAccent;

    // 1. Celestial Multi-Layer Ambient Nebula Glow
    if (glowOpacity > 0.01) {
      final Paint glowPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            primary.withValues(alpha: 0.45 * glowOpacity * pulse),
            secondary.withValues(alpha: 0.24 * glowOpacity * pulse),
            tertiary.withValues(alpha: 0.08 * glowOpacity * pulse),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.45, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 1.38));

      canvas.drawCircle(Offset(cx, cy), r * 1.35, glowPaint);
    }

    // 2. Rotating 12-Fold Celestial Starburst Rays (Diamond-pointed corona)
    final Paint rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const int rayCount = 12;
    for (int i = 0; i < rayCount; i++) {
      final double angle = (i * 2 * math.pi / rayCount) + (rot * 0.06);
      final bool isMajor = (i % 3 == 0);
      final double len = isMajor ? r * 0.98 : (i % 2 == 0 ? r * 0.84 : r * 0.72);
      final double startR = r * 0.40;

      rayPaint
        ..strokeWidth = isMajor ? 1.6 : 1.0
        ..color = (isMajor ? tertiary : primary).withValues(
          alpha: (isMajor ? 0.35 : 0.18) * pulse,
        );

      final double x1 = cx + math.cos(angle) * startR;
      final double y1 = cy + math.sin(angle) * startR;
      final double x2 = cx + math.cos(angle) * len;
      final double y2 = cy + math.sin(angle) * len;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), rayPaint);
    }

    // 3. Sacred Cosmic Rune Ring (Outer Metallic Orbit & Ticks)
    if (showRuneRing) {
      final Paint outerRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..shader = SweepGradient(
          transform: GradientRotation(rot * 0.22),
          colors: <Color>[
            primary,
            tertiary,
            GuildPalette.gold,
            secondary,
            primary,
          ],
          stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.84));

      canvas.drawCircle(Offset(cx, cy), r * 0.84, outerRing);

      // Rotating Micro Rune Ticks along Outer Ring
      final Paint tickPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.square;

      const int tickCount = 24;
      for (int i = 0; i < tickCount; i++) {
        final double angle = (i * 2 * math.pi / tickCount) - (rot * 0.12);
        final bool isCardinal = (i % 6 == 0);
        final double innerR = isCardinal ? r * 0.88 : r * 0.85;
        final double outerR = isCardinal ? r * 0.96 : r * 0.91;

        tickPaint
          ..strokeWidth = isCardinal ? 1.8 : 0.9
          ..color = (isCardinal ? tertiary : secondary).withValues(
            alpha: (isCardinal ? 0.8 : 0.4) * pulse,
          );

        final double x1 = cx + math.cos(angle) * innerR;
        final double y1 = cy + math.sin(angle) * innerR;
        final double x2 = cx + math.cos(angle) * outerR;
        final double y2 = cy + math.sin(angle) * outerR;
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);
      }

      // Counter-Rotating Inner Tachyon Ring
      final Paint innerRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = secondary.withValues(alpha: 0.42 * pulse);

      canvas.drawCircle(Offset(cx, cy), r * 0.68, innerRing);
    }

    // 4. Multi-Layer Sculpted Angelic Wing Blades (Left & Right Flanks)
    final Paint wingShader = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          primary.withValues(alpha: 0.88),
          secondary.withValues(alpha: 0.55),
          GuildPalette.celestialVoid.withValues(alpha: 0.75),
        ],
        stops: const <double>[0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.75));

    // Outer Primary Flight Blade (Left)
    final Path leftWingPrimary = Path();
    leftWingPrimary.moveTo(cx - r * 0.08, cy + r * 0.12);
    leftWingPrimary.cubicTo(
      cx - r * 0.36,
      cy - r * 0.05,
      cx - r * 0.68,
      cy - r * 0.35,
      cx - r * 0.76,
      cy - r * 0.64,
    );
    leftWingPrimary.cubicTo(
      cx - r * 0.54,
      cy - r * 0.48,
      cx - r * 0.32,
      cy - r * 0.28,
      cx - r * 0.08,
      cy - r * 0.12,
    );
    leftWingPrimary.close();
    canvas.drawPath(leftWingPrimary, wingShader);

    // Secondary Mid-Feather (Left)
    final Path leftWingSecondary = Path();
    leftWingSecondary.moveTo(cx - r * 0.08, cy + r * 0.22);
    leftWingSecondary.cubicTo(
      cx - r * 0.32,
      cy + r * 0.08,
      cx - r * 0.58,
      cy - r * 0.16,
      cx - r * 0.64,
      cy - r * 0.40,
    );
    leftWingSecondary.cubicTo(
      cx - r * 0.46,
      cy - r * 0.26,
      cx - r * 0.26,
      cy - r * 0.10,
      cx - r * 0.08,
      cy - r * 0.02,
    );
    leftWingSecondary.close();
    canvas.drawPath(leftWingSecondary, wingShader);

    // Mirrored Flight Blades (Right)
    final Path rightWingPrimary = Path();
    rightWingPrimary.moveTo(cx + r * 0.08, cy + r * 0.12);
    rightWingPrimary.cubicTo(
      cx + r * 0.36,
      cy - r * 0.05,
      cx + r * 0.68,
      cy - r * 0.35,
      cx + r * 0.76,
      cy - r * 0.64,
    );
    rightWingPrimary.cubicTo(
      cx + r * 0.54,
      cy - r * 0.48,
      cx + r * 0.32,
      cy - r * 0.28,
      cx + r * 0.08,
      cy - r * 0.12,
    );
    rightWingPrimary.close();
    canvas.drawPath(rightWingPrimary, wingShader);

    final Path rightWingSecondary = Path();
    rightWingSecondary.moveTo(cx + r * 0.08, cy + r * 0.22);
    rightWingSecondary.cubicTo(
      cx + r * 0.32,
      cy + r * 0.08,
      cx + r * 0.58,
      cy - r * 0.16,
      cx + r * 0.64,
      cy - r * 0.40,
    );
    rightWingSecondary.cubicTo(
      cx + r * 0.46,
      cy - r * 0.26,
      cx + r * 0.26,
      cy - r * 0.10,
      cx + r * 0.08,
      cy - r * 0.02,
    );
    rightWingSecondary.close();
    canvas.drawPath(rightWingSecondary, wingShader);

    // Luminous Wing Spine Highlights
    final Paint wingSpine = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[tertiary, primary.withValues(alpha: 0.1)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.7));

    canvas.drawPath(leftWingPrimary, wingSpine);
    canvas.drawPath(rightWingPrimary, wingSpine);

    // 5. Stylized PBR Heraldic Aegis Shield
    final Path shieldPath = Path();
    shieldPath.moveTo(cx, cy - r * 0.58);
    shieldPath.lineTo(cx + r * 0.48, cy - r * 0.32);
    shieldPath.quadraticBezierTo(
      cx + r * 0.46,
      cy + r * 0.25,
      cx,
      cy + r * 0.64,
    );
    shieldPath.quadraticBezierTo(
      cx - r * 0.46,
      cy + r * 0.25,
      cx - r * 0.48,
      cy - r * 0.32,
    );
    shieldPath.close();

    // Shield Deep Ambient Drop Shadow
    canvas.drawShadow(shieldPath, Colors.black, 8.0, true);

    // Shield Obsidian Core Fill
    final Paint shieldFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          GuildPalette.celestialSurface.withValues(alpha: 0.98),
          secondary.withValues(alpha: 0.50),
          GuildPalette.celestialVoid.withValues(alpha: 0.98),
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.65));

    canvas.drawPath(shieldPath, shieldFill);

    // Inset Carbon Grid / Cyber-Texture & Shimmer Sweep clipped to Shield
    canvas.save();
    canvas.clipPath(shieldPath);

    final Paint cyberGrid = Paint()
      ..color = primary.withValues(alpha: 0.07)
      ..strokeWidth = 0.8;

    for (double d = -r; d <= r; d += r * 0.15) {
      canvas.drawLine(
        Offset(cx + d - r * 0.5, cy - r * 0.6),
        Offset(cx + d + r * 0.5, cy + r * 0.6),
        cyberGrid,
      );
    }

    // Dynamic Specular Light Sweep
    final double sweepX = cx - r * 1.2 + (progress * r * 2.8);
    final Paint shimmerSweep = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.transparent,
          Colors.white.withValues(alpha: 0.20 * pulse),
          tertiary.withValues(alpha: 0.35 * pulse),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.42, 0.58, 1.0],
      ).createShader(Rect.fromLTWH(sweepX - r * 0.3, cy - r * 0.6, r * 0.6, r * 1.3));

    canvas.drawRect(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.8), shimmerSweep);

    // Vertical Center Ridge Line
    final Paint ridgeLine = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          tertiary.withValues(alpha: 0.6 * pulse),
          primary.withValues(alpha: 0.25),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(cx - 1, cy - r * 0.58, 2, r * 1.2))
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(cx, cy - r * 0.56), Offset(cx, cy + r * 0.60), ridgeLine);

    canvas.restore();

    // Shield Beveled Metallic Rim (Outer & Inner)
    final Paint shieldOuterRim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          tertiary,
          primary,
          GuildPalette.gold,
          secondary,
        ],
        stops: const <double>[0.0, 0.35, 0.70, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.65));

    canvas.drawPath(shieldPath, shieldOuterRim);

    final Paint shieldInnerRim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.white.withValues(alpha: 0.42 * pulse);

    canvas.drawPath(shieldPath, shieldInnerRim);

    // 6. Faceted Center Gem Core & Specular Flare
    final double gemR = r * 0.22 * pulse;
    final Path gemPath = Path();
    for (int i = 0; i < 8; i++) {
      final double a = (i * 2 * math.pi / 8) + (math.pi / 8);
      final double gx = cx + math.cos(a) * gemR;
      final double gy = cy + math.sin(a) * gemR;
      if (i == 0) {
        gemPath.moveTo(gx, gy);
      } else {
        gemPath.lineTo(gx, gy);
      }
    }
    gemPath.close();

    // Gem Core Radiant Aura
    final Paint gemGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white,
          tertiary.withValues(alpha: 0.8),
          primary.withValues(alpha: 0.4),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.35, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: gemR * 2.2));

    canvas.drawCircle(Offset(cx, cy), gemR * 2.0, gemGlow);

    // Gem Bevel Fill
    final Paint gemFill = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        center: const Alignment(-0.35, -0.35),
        colors: <Color>[
          Colors.white,
          tertiary,
          primary,
          secondary,
        ],
        stops: const <double>[0.0, 0.28, 0.68, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: gemR));

    canvas.drawPath(gemPath, gemFill);

    // Gem Internal Facet Seams
    final Paint facetLine = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 0.8;

    for (int i = 0; i < 8; i++) {
      final double a = (i * 2 * math.pi / 8) + (math.pi / 8);
      canvas.drawLine(
        Offset(cx, cy),
        Offset(cx + math.cos(a) * gemR, cy + math.sin(a) * gemR),
        facetLine,
      );
    }

    final Paint gemRim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = LinearGradient(
        colors: <Color>[Colors.white, tertiary, primary],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: gemR));

    canvas.drawPath(gemPath, gemRim);
  }

  @override
  bool shouldRepaint(covariant GuildCelestialEmblemPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.tier != tier ||
        oldDelegate.monogram != monogram ||
        oldDelegate.glowOpacity != glowOpacity ||
        oldDelegate.showRuneRing != showRuneRing;
  }
}

/// Animated Celestial Guild Emblem Widget with breathing aura, PBR metallic depth,
/// monogram crest, and haptic feedback interaction.
class GuildCelestialEmblem extends StatefulWidget {
  const GuildCelestialEmblem({
    super.key,
    required this.level,
    this.monogram = '⚔️',
    this.size = 64.0,
    this.showGlow = true,
    this.onTap,
    this.tooltip,
    this.interactive = true,
  });

  final int level;
  final String monogram;
  final double size;
  final bool showGlow;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool interactive;

  @override
  State<GuildCelestialEmblem> createState() => _GuildCelestialEmblemState();
}

class _GuildCelestialEmblemState extends State<GuildCelestialEmblem>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.interactive) return;
    HapticFeedback.lightImpact();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final GuildPrestigeTier tier = GuildPrestigeTier.fromLevel(widget.level);
    final String labelTooltip = widget.tooltip ?? '${tier.label} - Sv.${widget.level}';

    return Semantics(
      label: 'Lonca Arması: ${tier.label}, Seviye ${widget.level}',
      button: widget.onTap != null,
      child: Tooltip(
        message: labelTooltip,
        child: GestureDetector(
          onTapDown: widget.interactive && widget.onTap != null
              ? (_) => setState(() => _pressed = true)
              : null,
          onTapUp: widget.interactive && widget.onTap != null
              ? (_) => setState(() => _pressed = false)
              : null,
          onTapCancel: widget.interactive && widget.onTap != null
              ? () => setState(() => _pressed = false)
              : null,
          onTap: widget.interactive && widget.onTap != null ? _handleTap : null,
          child: AnimatedScale(
            scale: _pressed ? 0.94 : 1.0,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            child: AnimatedBuilder(
              animation: _anim,
              builder: (BuildContext context, Widget? child) {
                return SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      CustomPaint(
                        size: Size(widget.size, widget.size),
                        painter: GuildCelestialEmblemPainter(
                          progress: _anim.value,
                          tier: tier,
                          monogram: widget.monogram,
                          glowOpacity: widget.showGlow ? 0.85 : 0.0,
                        ),
                      ),
                      // Center Monogram or Crest Icon
                      Center(
                        child: Text(
                          widget.monogram,
                          style: TextStyle(
                            fontSize: widget.size * 0.32,
                            fontWeight: FontWeight.w900,
                            shadows: <Shadow>[
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.9),
                                blurRadius: 8,
                                offset: const Offset(0, 1),
                              ),
                              Shadow(
                                color: tier.primaryAccent.withValues(alpha: 0.85),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Fluttering Celestial Swallowtail Guild Cloth Banner Painter.
/// Features dynamic aerodynamic cloth wave simulation, jacquard cyber-weave lattice,
/// dual embroidered metallic trims, hanging rod with jeweled finials, and golden fringe.
class GuildBannerClothPainter extends CustomPainter {
  const GuildBannerClothPainter({
    required this.waveProgress,
    required this.tier,
    this.monumentLevel = 0,
    this.shimmerProgress = 0.0,
  });

  final double waveProgress;
  final GuildPrestigeTier tier;
  final int monumentLevel;
  final double shimmerProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    if (w <= 0 || h <= 0) return;

    final Color primary = tier.primaryAccent;
    final Color secondary = tier.secondaryAccent;
    final Color tertiary = tier.tertiaryAccent;

    // Aerodynamic dual-frequency wind physics
    final double waveL = math.sin(waveProgress * 2 * math.pi) * 3.6;
    final double waveR = math.cos(waveProgress * 2 * math.pi) * 3.6;
    final double waveM = math.sin((waveProgress + 0.25) * 2 * math.pi) * 2.4;

    const double rodY = 9.0;
    const double clothTopY = 12.0;
    final double tipL_Y = h - 20.0 + waveL;
    final double tipR_Y = h - 20.0 + waveR;
    final double notchY = h - 38.0 + waveM;

    // Swallowtail cloth silhouette with natural fabric drape curves
    final Path cloth = Path();
    cloth.moveTo(0, clothTopY);
    cloth.lineTo(w, clothTopY);
    cloth.quadraticBezierTo(w + waveR * 0.4, (clothTopY + tipR_Y) * 0.5, w + waveR * 0.2, tipR_Y);
    cloth.lineTo(w * 0.5, notchY);
    cloth.lineTo(waveL * 0.2, tipL_Y);
    cloth.quadraticBezierTo(waveL * 0.4, (clothTopY + tipL_Y) * 0.5, 0, clothTopY);
    cloth.close();

    // 1. Soft Fabric Drop Shadow
    canvas.drawShadow(cloth, Colors.black.withValues(alpha: 0.75), 10.0, false);

    // 2. Cloth Base Fill with Rich Celestial Gradient
    final Paint clothFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          primary.withValues(alpha: 0.40),
          GuildPalette.celestialSurface.withValues(alpha: 0.94),
          GuildPalette.celestialVoid.withValues(alpha: 0.98),
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, clothTopY, w, h - clothTopY));

    canvas.drawPath(cloth, clothFill);

    // 3. Dynamic Fabric Fold Shading (Sinusoidal ripple illumination)
    final double foldShift = waveProgress * 2 * math.pi;
    final double fold1 = math.sin(foldShift) * 0.12;
    final double fold2 = math.cos(foldShift) * 0.12;

    final Paint foldShading = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: <Color>[
          Colors.white.withValues(alpha: (0.08 + fold1).clamp(0.0, 0.22)),
          Colors.black.withValues(alpha: 0.18),
          Colors.white.withValues(alpha: (0.12 + fold2).clamp(0.0, 0.24)),
          Colors.black.withValues(alpha: 0.20),
          Colors.white.withValues(alpha: (0.06 - fold1).clamp(0.0, 0.20)),
        ],
        stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, clothTopY, w, h - clothTopY));

    canvas.drawPath(cloth, foldShading);

    // 4. Jacquard Cyber-Lattice & Light Sweep clipped to Cloth
    canvas.save();
    canvas.clipPath(cloth);

    final Paint jacquard = Paint()
      ..color = primary.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;

    const double step = 14.0;
    for (double x = -h; x < w + h; x += step) {
      canvas.drawLine(Offset(x, clothTopY), Offset(x + h, h), jacquard);
      canvas.drawLine(Offset(x, h), Offset(x + h, clothTopY), jacquard);
    }

    // Dynamic Iridescent Shimmer Sweep
    final double effShimmer = shimmerProgress > 0 ? shimmerProgress : waveProgress;
    final double sweepX = -w * 0.5 + effShimmer * (w * 2.0);
    final Paint shimmerBeam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.transparent,
          tertiary.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.26),
          primary.withValues(alpha: 0.15),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.4, 0.5, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(sweepX - w * 0.4, clothTopY, w * 0.8, h));

    canvas.drawRect(Rect.fromLTWH(0, clothTopY, w, h), shimmerBeam);

    canvas.restore();

    // 5. Ornate Embroidered Metallic Border Trim
    final Paint outerBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          tertiary,
          primary,
          secondary,
          GuildPalette.gold,
        ],
        stops: const <double>[0.0, 0.38, 0.72, 1.0],
      ).createShader(Rect.fromLTWH(0, clothTopY, w, h - clothTopY));

    canvas.drawPath(cloth, outerBorder);

    // Inset Decorative Stitch
    final Path innerCloth = Path();
    const double inset = 3.2;
    innerCloth.moveTo(inset, clothTopY + inset);
    innerCloth.lineTo(w - inset, clothTopY + inset);
    innerCloth.lineTo(w - inset + waveR * 0.2, tipR_Y - inset);
    innerCloth.lineTo(w * 0.5, notchY - inset);
    innerCloth.lineTo(inset + waveL * 0.2, tipL_Y - inset);
    innerCloth.close();

    final Paint innerBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = tertiary.withValues(alpha: 0.36);

    canvas.drawPath(innerCloth, innerBorder);

    // 6. Swallowtail Golden Fringe Tassels
    final Paint tasselPaint = Paint()
      ..color = GuildPalette.gold
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 4; i++) {
      final double t = i / 3.0;
      final double lx = (inset + waveL * 0.2) * (1 - t) + (w * 0.5) * t;
      final double ly = (tipL_Y - inset) * (1 - t) + (notchY - inset) * t;
      canvas.drawLine(Offset(lx, ly), Offset(lx, ly + 3.2), tasselPaint);

      final double rx = (w * 0.5) * (1 - t) + (w - inset + waveR * 0.2) * t;
      final double ry = (notchY - inset) * (1 - t) + (tipR_Y - inset) * t;
      canvas.drawLine(Offset(rx, ry), Offset(rx, ry + 3.2), tasselPaint);
    }

    // 7. Hanging Rod Mounting Rings (Eyelets)
    final Paint eyeletPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = GuildPalette.gold;

    canvas.drawCircle(Offset(w * 0.22, rodY + 2.0), 2.2, eyeletPaint);
    canvas.drawCircle(Offset(w * 0.78, rodY + 2.0), 2.2, eyeletPaint);

    // 8. Metallic Crossbar Rod with Cylindrical Highlights
    final Rect rodRect = Rect.fromLTWH(-7.0, rodY - 2.5, w + 14.0, 5.0);
    final RRect rodRRect = RRect.fromRectAndRadius(rodRect, const Radius.circular(2.5));

    final Paint rodPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white,
          GuildPalette.gold,
          tier.secondaryAccent,
          const Color(0xFF3E2723),
        ],
        stops: const <double>[0.0, 0.32, 0.75, 1.0],
      ).createShader(rodRect);

    canvas.drawRRect(rodRRect, rodPaint);

    final Paint rodHighlight = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..strokeWidth = 0.8;

    canvas.drawLine(Offset(-6, rodY - 1.5), Offset(w + 6, rodY - 1.5), rodHighlight);

    // 9. Ornate Rod Jeweled Finials (Left & Right)
    final List<Offset> finialCenters = <Offset>[
      const Offset(-7.0, rodY),
      Offset(w + 7.0, rodY),
    ];

    for (final Offset center in finialCenters) {
      final Paint finialGold = Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.3),
          colors: <Color>[
            Colors.white,
            GuildPalette.gold,
            const Color(0xFFB45309),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 4.5));

      canvas.drawCircle(center, 4.0, finialGold);

      final Paint finialGem = Paint()..color = primary;
      canvas.drawCircle(center, 1.8, finialGem);

      final Paint glint = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(center.dx - 0.7, center.dy - 0.7), 0.6, glint);
    }
  }

  @override
  bool shouldRepaint(covariant GuildBannerClothPainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress ||
        oldDelegate.tier != tier ||
        oldDelegate.monumentLevel != monumentLevel ||
        oldDelegate.shimmerProgress != shimmerProgress;
  }
}

/// Animated 2027 Aion 2 Celestial Guild Banner Widget.
/// Displays aerodynamic waving cloth, prestige emblem crest, guild typography,
/// monument standing badge, and interactive touch response.
class GuildCelestialBanner extends StatefulWidget {
  const GuildCelestialBanner({
    super.key,
    required this.guildName,
    required this.level,
    this.monumentLevel = 0,
    this.width = 110.0,
    this.height = 145.0,
    this.isCompact = false,
    this.onTap,
    this.motto,
    this.memberCount,
    this.showMonumentBadge = true,
  });

  final String guildName;
  final int level;
  final int monumentLevel;
  final double width;
  final double height;
  final bool isCompact;
  final VoidCallback? onTap;
  final String? motto;
  final int? memberCount;
  final bool showMonumentBadge;

  @override
  State<GuildCelestialBanner> createState() => _GuildCelestialBannerState();
}

class _GuildCelestialBannerState extends State<GuildCelestialBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _handleTap() {
    HapticFeedback.selectionClick();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final GuildPrestigeTier tier = GuildPrestigeTier.fromLevel(widget.level);
    final String monogram = widget.guildName.isNotEmpty
        ? widget.guildName.characters.first.toUpperCase()
        : '⚔️';

    final Widget bannerContent = SizedBox(
      width: widget.width,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: <Widget>[
          // Fluttering Aerodynamic Cloth
          Positioned.fill(
            child: CustomPaint(
              painter: GuildBannerClothPainter(
                waveProgress: _anim.value,
                tier: tier,
                monumentLevel: widget.monumentLevel,
              ),
            ),
          ),
          // Content Stack
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 4 : 6,
              vertical: widget.isCompact ? 6 : 8,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 6),
                GuildCelestialEmblem(
                  level: widget.level,
                  monogram: monogram,
                  size: widget.isCompact
                      ? 36.0
                      : (widget.width >= 120.0 ? 52.0 : 46.0),
                  showGlow: true,
                  interactive: false,
                ),
                const SizedBox(height: 4),
                // Guild Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    widget.guildName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: widget.isCompact ? 9.5 : 11.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: GuildPalette.textHi,
                      shadows: <Shadow>[
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.85),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                        Shadow(
                          color: tier.primaryAccent.withValues(alpha: 0.8),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 3),
                // Badges Row (Level & Monument Standing)
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: tier.primaryAccent.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: tier.primaryAccent.withValues(alpha: 0.60),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'Sv.${widget.level}',
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                          color: tier.primaryAccent,
                        ),
                      ),
                    ),
                    if (widget.showMonumentBadge && widget.monumentLevel > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: GuildPalette.gold.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: GuildPalette.gold.withValues(alpha: 0.70),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              '🏛️',
                              style: TextStyle(fontSize: widget.isCompact ? 6 : 7),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'M${widget.monumentLevel}',
                              style: const TextStyle(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                                color: GuildPalette.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                // Optional Motto or Subtitle
                if (widget.motto != null && !widget.isCompact) ...<Widget>[
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      widget.motto!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 8.0,
                        fontStyle: FontStyle.italic,
                        color: GuildPalette.titanium.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.onTap != null) {
      return Semantics(
        label: 'Lonca Sancağı: ${widget.guildName}, ${tier.label}, Seviye ${widget.level}',
        button: true,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: _handleTap,
          child: AnimatedScale(
            scale: _pressed ? 0.96 : 1.0,
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOutCubic,
            child: bannerContent,
          ),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (BuildContext context, Widget? child) => bannerContent,
    );
  }
}

