import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Colosseum visual theme moods.
enum ColosseumThemeMood {
  abyssCrimson,
  sanctumGold,
  obsidianCyan,
  eclipseViolet;

  Color get primaryAccent {
    switch (this) {
      case ColosseumThemeMood.abyssCrimson:
        return const Color(0xFFFF1744);
      case ColosseumThemeMood.sanctumGold:
        return const Color(0xFFFFD700);
      case ColosseumThemeMood.obsidianCyan:
        return const Color(0xFF00E5FF);
      case ColosseumThemeMood.eclipseViolet:
        return const Color(0xFFB388FF);
    }
  }

  Color get secondaryAccent {
    switch (this) {
      case ColosseumThemeMood.abyssCrimson:
        return const Color(0xFFFF5252);
      case ColosseumThemeMood.sanctumGold:
        return const Color(0xFFFFAB00);
      case ColosseumThemeMood.obsidianCyan:
        return const Color(0xFF18FFFF);
      case ColosseumThemeMood.eclipseViolet:
        return const Color(0xFF7C4DFF);
    }
  }

  List<Color> get skyGradient {
    switch (this) {
      case ColosseumThemeMood.abyssCrimson:
        return const <Color>[
          Color(0xFF060307),
          Color(0xFF150A12),
          Color(0xFF260D18),
        ];
      case ColosseumThemeMood.sanctumGold:
        return const <Color>[
          Color(0xFF070709),
          Color(0xFF14120C),
          Color(0xFF221A0F),
        ];
      case ColosseumThemeMood.obsidianCyan:
        return const <Color>[
          Color(0xFF05080E),
          Color(0xFF0B1422),
          Color(0xFF102035),
        ];
      case ColosseumThemeMood.eclipseViolet:
        return const <Color>[
          Color(0xFF07040C),
          Color(0xFF120B20),
          Color(0xFF1E1032),
        ];
    }
  }
}

/// Cinematic Aion-2 Colosseum Architecture Custom Painter.
/// Paints colossal stone archways, floating runic monoliths, arena duel dais, braziers, and volumetric god-rays.
class ColosseumIllustrationPainter extends CustomPainter {
  const ColosseumIllustrationPainter({
    required this.animationProgress,
    this.mood = ColosseumThemeMood.abyssCrimson,
    this.showDais = true,
    this.showMonoliths = true,
  });

  final double animationProgress;
  final ColosseumThemeMood mood;
  final bool showDais;
  final bool showMonoliths;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double cx = w / 2;
    final double cy = h * 0.65;

    // 1. OLED Deep Fantasy Sky
    final Paint skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: mood.skyGradient,
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), skyPaint);

    // 2. Volumetric God-Rays
    final Paint rayPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          mood.primaryAccent.withValues(alpha: 0.22),
          mood.secondaryAccent.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    for (int i = 0; i < 6; i++) {
      final double sway = math.sin((animationProgress + i * 0.16) * 2 * math.pi) * 16;
      final Path ray = Path();
      ray.moveTo(cx - 120 + i * 48, 0);
      ray.lineTo(cx - 95 + i * 48, 0);
      ray.lineTo(cx - 40 + i * 70 + sway, h * 0.88);
      ray.lineTo(cx - 95 + i * 70 + sway, h * 0.88);
      ray.close();
      canvas.drawPath(ray, rayPaint);
    }

    // 3. Colossal Distant Colosseum Archways Silhouette
    final Paint archPaint = Paint()
      ..color = const Color(0xFF0A0E18)
      ..style = PaintingStyle.fill;
    final Paint archBorder = Paint()
      ..color = mood.primaryAccent.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double archY = h * 0.38;
    final int archCount = 7;
    final double archSpacing = w / (archCount - 1);

    for (int i = 0; i < archCount; i++) {
      final double ax = i * archSpacing;
      final double archW = archSpacing * 0.65;
      final double archH = h * 0.22;
      final Rect archRect = Rect.fromCenter(
        center: Offset(ax, archY),
        width: archW,
        height: archH,
      );
      final RRect rrect = RRect.fromRectAndCorners(
        archRect,
        topLeft: Radius.circular(archW / 2),
        topRight: Radius.circular(archW / 2),
      );
      canvas.drawRRect(rrect, archPaint);
      canvas.drawRRect(rrect, archBorder);
    }

    // 4. Arena Amphitheater Tier Steps
    final Paint tierPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          const Color(0xFF141A28),
          const Color(0xFF0A0D15),
        ],
      ).createShader(Rect.fromLTWH(0, archY + h * 0.1, w, h * 0.2));

    final Path tierPath = Path();
    tierPath.moveTo(0, archY + h * 0.1);
    tierPath.lineTo(w, archY + h * 0.1);
    tierPath.lineTo(w, h * 0.7);
    tierPath.lineTo(0, h * 0.7);
    tierPath.close();
    canvas.drawPath(tierPath, tierPaint);

    // 5. Floating Shattered Monolith Basalt Stones with Glowing Runes
    if (showMonoliths) {
      final Paint stonePaint = Paint()
        ..color = const Color(0xFF171E2E)
        ..style = PaintingStyle.fill;
      final Paint stoneGlow = Paint()
        ..color = mood.primaryAccent.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      final List<Offset> monolithOffsets = <Offset>[
        Offset(w * 0.14, h * (0.28 + 0.03 * math.sin(animationProgress * 2 * math.pi))),
        Offset(w * 0.86, h * (0.25 + 0.03 * math.cos(animationProgress * 2 * math.pi))),
        Offset(w * 0.28, h * (0.22 + 0.02 * math.cos((animationProgress + 0.4) * 2 * math.pi))),
        Offset(w * 0.72, h * (0.20 + 0.02 * math.sin((animationProgress + 0.4) * 2 * math.pi))),
      ];

      for (final Offset mo in monolithOffsets) {
        final Path stone = Path();
        stone.moveTo(mo.dx, mo.dy - 16);
        stone.lineTo(mo.dx + 12, mo.dy - 6);
        stone.lineTo(mo.dx + 8, mo.dy + 14);
        stone.lineTo(mo.dx - 10, mo.dy + 16);
        stone.lineTo(mo.dx - 14, mo.dy - 4);
        stone.close();
        canvas.drawPath(stone, stonePaint);
        canvas.drawPath(stone, stoneGlow);

        // Core glowing rune on stone
        final Paint runeDot = Paint()
          ..color = mood.primaryAccent.withValues(alpha: 0.85);
        canvas.drawCircle(mo, 2.0, runeDot);
      }
    }

    // 6. Arena Duel Dais / Elliptical Platform
    if (showDais) {
      final Rect daisRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: w * 0.82,
        height: h * 0.45,
      );

      final Paint daisPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFF222B42),
            const Color(0xFF141928),
            const Color(0xFF090C14),
          ],
          stops: const <double>[0.0, 0.65, 1.0],
        ).createShader(daisRect);
      canvas.drawOval(daisRect, daisPaint);

      // Glowing Runic Rim & Inscribed Summoning Ring
      final Paint rimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..shader = SweepGradient(
          colors: <Color>[
            mood.primaryAccent,
            mood.secondaryAccent,
            Colors.white.withValues(alpha: 0.9),
            mood.primaryAccent,
          ],
        ).createShader(daisRect);
      canvas.drawOval(daisRect, rimPaint);

      // Concentric Runic Rings
      final Paint innerRing = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = mood.primaryAccent.withValues(alpha: 0.65);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: w * 0.55, height: h * 0.28),
        innerRing,
      );

      // Rotating Runic Constellation Glyphs
      final int glyphCount = 8;
      final double rot = animationProgress * 2 * math.pi;
      final Paint glyphPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.85);

      for (int i = 0; i < glyphCount; i++) {
        final double angle = (i * 2 * math.pi / glyphCount) + rot;
        final double gx = cx + math.cos(angle) * (w * 0.275);
        final double gy = cy + math.sin(angle) * (h * 0.14);
        canvas.drawCircle(Offset(gx, gy), 2.2, glyphPaint);
      }
    }

    // 7. Colosseum Braziers & Rising Embers
    final Paint brazierPaint = Paint()..color = const Color(0xFF2A1C16);
    final double leftBrazierX = w * 0.12;
    final double rightBrazierX = w * 0.88;
    final double brazierY = h * 0.58;

    canvas.drawRect(Rect.fromCenter(center: Offset(leftBrazierX, brazierY), width: 14, height: 24), brazierPaint);
    canvas.drawRect(Rect.fromCenter(center: Offset(rightBrazierX, brazierY), width: 14, height: 24), brazierPaint);

    final Paint flamePaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white,
          mood.primaryAccent,
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(leftBrazierX, brazierY - 14), radius: 18));
    canvas.drawCircle(Offset(leftBrazierX, brazierY - 14), 16, flamePaint);

    final Paint flamePaintR = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white,
          mood.primaryAccent,
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(rightBrazierX, brazierY - 14), radius: 18));
    canvas.drawCircle(Offset(rightBrazierX, brazierY - 14), 16, flamePaintR);

    // Rising Embers
    final math.Random rng = math.Random(77);
    final Paint emberPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 22; i++) {
      final double progress = (animationProgress + rng.nextDouble()) % 1.0;
      final double px = w * 0.15 + rng.nextDouble() * (w * 0.7);
      final double py = (h * 0.8) - progress * (h * 0.5);
      final double alpha = math.sin(progress * math.pi);
      emberPaint.color = (i % 2 == 0 ? mood.primaryAccent : const Color(0xFFFFD54F))
          .withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(px, py), 1.0 + rng.nextDouble() * 1.5, emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ColosseumIllustrationPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.mood != mood ||
        oldDelegate.showDais != showDais ||
        oldDelegate.showMonoliths != showMonoliths;
  }
}

/// Mobile OLED Backdrop container with live animated Colosseum painter.
class PvpColosseumBackdrop extends StatefulWidget {
  const PvpColosseumBackdrop({
    super.key,
    required this.child,
    this.mood = ColosseumThemeMood.abyssCrimson,
    this.showDais = true,
    this.showMonoliths = true,
  });

  final Widget child;
  final ColosseumThemeMood mood;
  final bool showDais;
  final bool showMonoliths;

  @override
  State<PvpColosseumBackdrop> createState() => _PvpColosseumBackdropState();
}

class _PvpColosseumBackdropState extends State<PvpColosseumBackdrop>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _anim,
            builder: (BuildContext context, Widget? _) {
              return CustomPaint(
                painter: ColosseumIllustrationPainter(
                  animationProgress: _anim.value,
                  mood: widget.mood,
                  showDais: widget.showDais,
                  showMonoliths: widget.showMonoliths,
                ),
              );
            },
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.black.withValues(alpha: 0.25),
          ),
        ),
        widget.child,
      ],
    );
  }
}

/// Rich arena card illustration banner.
class ColosseumCardIllustration extends StatelessWidget {
  const ColosseumCardIllustration({
    super.key,
    required this.title,
    required this.subtitle,
    this.mood = ColosseumThemeMood.abyssCrimson,
    this.height = 100,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final ColosseumThemeMood mood;
  final double height;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: mood.primaryAccent.withValues(alpha: 0.4),
            width: 1.0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: <Widget>[
            // Canvas backdrop
            Positioned.fill(
              child: CustomPaint(
                painter: ColosseumIllustrationPainter(
                  animationProgress: 0.35,
                  mood: mood,
                  showDais: true,
                  showMonoliths: false,
                ),
              ),
            ),
            // Vignette overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: <Color>[
                      Colors.black.withValues(alpha: 0.85),
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
            ),
            // Information row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: mood.primaryAccent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: mood.primaryAccent, width: 1.2),
                    ),
                    child: Icon(Icons.stadium_rounded, color: mood.primaryAccent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
