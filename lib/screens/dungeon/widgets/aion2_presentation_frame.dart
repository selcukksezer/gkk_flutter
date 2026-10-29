import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../models/dungeon_model.dart';
import '../../../theme/app_colors.dart';
import 'aion2_boss_illustration_catalog.dart';
import 'dungeon_battle_effects.dart';

/// Painter for AAA Gold Filigree borders and ornate corner acanthus flourishes.
class Aion2GoldFiligreePainter extends CustomPainter {
  const Aion2GoldFiligreePainter({
    this.primaryGold = const Color(0xFFFFD700),
    this.deepGold = const Color(0xFFB8860B),
    this.highlightGold = const Color(0xFFFFF4B8),
    this.strokeWidth = 1.4,
    this.cornerSize = 24.0,
    this.showCrest = true,
    this.showGems = true,
  });

  final Color primaryGold;
  final Color deepGold;
  final Color highlightGold;
  final double strokeWidth;
  final double cornerSize;
  final bool showCrest;
  final bool showGems;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Rect rect = Offset.zero & size;
    final double pad = strokeWidth / 2 + 1;
    final Rect innerRect = Rect.fromLTRB(
      pad,
      pad,
      size.width - pad,
      size.height - pad,
    );

    // 1. Dual-tone Gold Gradient for Outer Border
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          highlightGold.withValues(alpha: 0.95),
          primaryGold,
          deepGold,
          primaryGold.withValues(alpha: 0.8),
          highlightGold.withValues(alpha: 0.95),
        ],
        stops: const <double>[0.0, 0.28, 0.52, 0.78, 1.0],
      ).createShader(rect);

    final RRect rrect = RRect.fromRectAndRadius(innerRect, const Radius.circular(14));
    canvas.drawRRect(rrect, borderPaint);

    // 2. Inner Inset Specular Hairline
    final Rect insetRect = innerRect.deflate(3.5);
    if (insetRect.width > 0 && insetRect.height > 0) {
      final Paint innerHairline = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = primaryGold.withValues(alpha: 0.28);
      canvas.drawRRect(
        RRect.fromRectAndRadius(insetRect, const Radius.circular(11)),
        innerHairline,
      );
    }

    // 3. Ornate Filigree Corner Ornaments (Top-Left, Top-Right, Bottom-Left, Bottom-Right)
    final double cs = cornerSize.clamp(14.0, math.min(size.width, size.height) * 0.45);
    _drawCornerFiligree(canvas, 0, 0, cs, 0); // TL
    _drawCornerFiligree(canvas, size.width, 0, cs, math.pi / 2); // TR
    _drawCornerFiligree(canvas, size.width, size.height, cs, math.pi); // BR
    _drawCornerFiligree(canvas, 0, size.height, cs, -math.pi / 2); // BL

    // 4. Center Top Filigree Crest / Diamond Jewel
    if (showCrest && size.width > 80) {
      _drawCenterCrest(canvas, size.width / 2, pad + 1);
    }
  }

  void _drawCornerFiligree(Canvas canvas, double cx, double cy, double cs, double rotation) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation);

    final Paint goldPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        colors: <Color>[highlightGold, primaryGold, deepGold],
      ).createShader(Rect.fromLTWH(0, 0, cs, cs));

    // Corner bracket flourish path
    final Path path = Path();
    path.moveTo(3, cs * 0.9);
    path.cubicTo(4, cs * 0.5, cs * 0.5, 4, cs * 0.9, 3);

    // Inner scroll loop
    path.moveTo(6, cs * 0.65);
    path.cubicTo(6, cs * 0.35, cs * 0.35, 6, cs * 0.65, 6);

    canvas.drawPath(path, goldPaint);

    // Corner Diamond Stud / Gem
    if (showGems) {
      final Path diamond = Path();
      const double gemSize = 3.5;
      diamond.moveTo(7, 7 - gemSize);
      diamond.lineTo(7 + gemSize, 7);
      diamond.lineTo(7, 7 + gemSize);
      diamond.lineTo(7 - gemSize, 7);
      diamond.close();

      final Paint gemFill = Paint()..color = highlightGold;
      canvas.drawPath(diamond, gemFill);

      final Paint gemGlow = Paint()
        ..color = primaryGold.withValues(alpha: 0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawCircle(const Offset(7, 7), gemSize * 0.8, gemGlow);
    }

    canvas.restore();
  }

  void _drawCenterCrest(Canvas canvas, double cx, double cy) {
    final Path crest = Path();
    const double cw = 14;
    const double ch = 6;
    crest.moveTo(cx - cw, cy);
    crest.lineTo(cx, cy + ch);
    crest.lineTo(cx + cw, cy);
    crest.lineTo(cx, cy - 2);
    crest.close();

    final Paint crestPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[deepGold, highlightGold, deepGold],
      ).createShader(Rect.fromLTWH(cx - cw, cy - 2, cw * 2, ch + 2));
    canvas.drawPath(crest, crestPaint);

    // Center jewel pip
    final Paint pipPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx, cy + 1.5), 1.5, pipPaint);
  }

  @override
  bool shouldRepaint(Aion2GoldFiligreePainter oldDelegate) =>
      oldDelegate.primaryGold != primaryGold ||
      oldDelegate.deepGold != deepGold ||
      oldDelegate.highlightGold != highlightGold ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.cornerSize != cornerSize ||
      oldDelegate.showCrest != showCrest ||
      oldDelegate.showGems != showGems;
}

/// AAA Glassmorphic Presentation Frame with Frost Blur & Gold Filigree Aesthetics.
class Aion2GlassmorphicFrame extends StatelessWidget {
  const Aion2GlassmorphicFrame({
    super.key,
    required this.child,
    this.primaryGold = const Color(0xFFFFD700),
    this.deepGold = const Color(0xFFB8860B),
    this.highlightGold = const Color(0xFFFFF4B8),
    this.accentGlow,
    this.borderRadius = 14.0,
    this.blurSigma = 12.0,
    this.padding = const EdgeInsets.all(12),
    this.showFiligree = true,
    this.showCrest = true,
    this.boxShadows,
  });

  final Widget child;
  final Color primaryGold;
  final Color deepGold;
  final Color highlightGold;
  final Color? accentGlow;
  final double borderRadius;
  final double blurSigma;
  final EdgeInsetsGeometry padding;
  final bool showFiligree;
  final bool showCrest;
  final List<BoxShadow>? boxShadows;

  @override
  Widget build(BuildContext context) {
    final Color glow = accentGlow ?? primaryGold;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadows ??
            <BoxShadow>[
              BoxShadow(
                color: glow.withValues(alpha: 0.16),
                blurRadius: 22,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Stack(
            children: <Widget>[
              // 1. Deep Obsidian Translucent Glass Gradient
              Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(borderRadius),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xDC121828),
                      Color(0xEA0B0F19),
                      Color(0xF5060810),
                    ],
                    stops: <double>[0.0, 0.45, 1.0],
                  ),
                ),
                child: child,
              ),

              // 2. Top-edge Specular Sheen (WCAG 2.2 AA Contrast Accent)
              Positioned(
                top: 0,
                left: 12,
                right: 12,
                height: 1.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        highlightGold.withValues(alpha: 0.6),
                        Colors.white.withValues(alpha: 0.8),
                        highlightGold.withValues(alpha: 0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Ornate Gold Filigree Overlay
              if (showFiligree)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: Aion2GoldFiligreePainter(
                        primaryGold: primaryGold,
                        deepGold: deepGold,
                        highlightGold: highlightGold,
                        showCrest: showCrest,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AAA Aion-2 Abyssal Boss Portrait Card with Animated Aura and Gold Filigree Frame.
class Aion2BossPortraitCard extends StatelessWidget {
  const Aion2BossPortraitCard({
    super.key,
    required this.boss,
    this.height = 140.0,
    this.width,
    this.animationProgress = 0.0,
    this.showLore = false,
    this.onTap,
  });

  final Aion2BossArtDefinition boss;
  final double height;
  final double? width;
  final double animationProgress;
  final bool showLore;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget card = SizedBox(
      height: height,
      width: width,
      child: Aion2GlassmorphicFrame(
        primaryGold: boss.goldFiligreeColor,
        deepGold: const Color(0xFFB8860B),
        highlightGold: const Color(0xFFFFF6B8),
        accentGlow: boss.glowColor,
        padding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 1. Procedural Abyssal Illustration Layer
            CustomPaint(
              painter: Aion2AbyssalIllustrationPainter(
                boss: boss,
                animationProgress: animationProgress,
                intensity: 1.0,
              ),
            ),

            // 2. Texture Asset Feathering if available
            Positioned.fill(
              child: Opacity(
                opacity: 0.28,
                child: Image.asset(
                  boss.fallbackDungeonAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),

            // 3. Dark Bottom Gradient for Text Legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                      const Color(0xFF060912).withValues(alpha: 0.95),
                    ],
                    stops: const <double>[0.3, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // 4. Boss Info & Thematic Badges
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  // Tier & Element Strip
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: boss.tier.color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: boss.tier.color.withValues(alpha: 0.65),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(boss.tier.icon, size: 10, color: boss.tier.color),
                            const SizedBox(width: 4),
                            Text(
                              boss.tier.label,
                              style: GoogleFonts.urbanist(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: boss.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: boss.accentColor.withValues(alpha: 0.45),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          boss.element.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: boss.accentColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),

                  // Boss Name
                  Text(
                    boss.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.urbanist(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.4,
                      shadows: <Shadow>[
                        Shadow(
                          color: boss.glowColor.withValues(alpha: 0.85),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),

                  // Boss Subtitle / Lore
                  Text(
                    showLore ? boss.loreQuote : '${boss.title} • Bölge ${boss.zone}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: boss.goldFiligreeColor.withValues(alpha: 0.9),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap != null) {
      card = GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      );
    }
    return card;
  }
}

/// Cinematic Aion-2 VS Intro Banner between Player and Abyssal Boss.
class Aion2BossIntroBanner extends StatelessWidget {
  const Aion2BossIntroBanner({
    super.key,
    required this.boss,
    required this.playerName,
    required this.playerLevel,
    required this.playerAsset,
    required this.playerColor,
    required this.animationProgress,
    this.slideProgress = 1.0,
    this.onSkip,
  });

  final Aion2BossArtDefinition boss;
  final String playerName;
  final int playerLevel;
  final String playerAsset;
  final Color playerColor;
  final double animationProgress;
  final double slideProgress;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Dual Duel Portraits: Player vs Abyssal Boss
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Player Portrait Card
            Transform.translate(
              offset: Offset(-260 * (1 - slideProgress), 0),
              child: _PortraitFrame(
                asset: playerAsset,
                name: playerName,
                tag: 'LV.$playerLevel KAHRAMAN',
                borderColor: playerColor,
                glowColor: playerColor,
                isPlayer: true,
              ),
            ),

            // Ornate VS Crest Emblem
            SizedBox(
              width: 90,
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  // Rotating Runic VS Ring
                  Transform.rotate(
                    angle: animationProgress * 2 * math.pi,
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: boss.goldFiligreeColor.withValues(alpha: 0.45),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),

                  // VS Shield Core
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          boss.goldFiligreeColor,
                          const Color(0xFFB8860B),
                          boss.abyssalDarkColor,
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: boss.glowColor.withValues(alpha: 0.55),
                          blurRadius: 18,
                        ),
                      ],
                      border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 1.5),
                    ),
                    child: const Center(
                      child: Text(
                        'VS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Abyssal Boss Portrait Card
            Transform.translate(
              offset: Offset(260 * (1 - slideProgress), 0),
              child: _PortraitFrame(
                asset: boss.fallbackDungeonAsset,
                name: boss.name,
                tag: boss.tier.label,
                borderColor: boss.goldFiligreeColor,
                glowColor: boss.glowColor,
                isPlayer: false,
                bossDef: boss,
                animationProgress: animationProgress,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Abyssal Boss Lore & Epithet Banner
        Aion2GlassmorphicFrame(
          primaryGold: boss.goldFiligreeColor,
          accentGlow: boss.glowColor,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(boss.tier.icon, size: 14, color: boss.goldFiligreeColor),
                  const SizedBox(width: 6),
                  Text(
                    '${boss.tier.label} • ${boss.title.toUpperCase()}',
                    style: GoogleFonts.urbanist(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: boss.goldFiligreeColor,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '„${boss.loreQuote}”',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFFCBD5E1),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PortraitFrame extends StatelessWidget {
  const _PortraitFrame({
    required this.asset,
    required this.name,
    required this.tag,
    required this.borderColor,
    required this.glowColor,
    required this.isPlayer,
    this.bossDef,
    this.animationProgress = 0.0,
  });

  final String asset;
  final String name;
  final String tag;
  final Color borderColor;
  final Color glowColor;
  final bool isPlayer;
  final Aion2BossArtDefinition? bossDef;
  final double animationProgress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 96,
          height: 108,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF0B101D),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: glowColor.withValues(alpha: 0.38),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (!isPlayer && bossDef != null)
                  CustomPaint(
                    painter: Aion2AbyssalIllustrationPainter(
                      boss: bossDef!,
                      animationProgress: animationProgress,
                      intensity: 0.85,
                    ),
                  )
                else
                  ColoredBox(color: const Color(0xFF090D18)),

                // Art image
                Opacity(
                  opacity: isPlayer ? 1.0 : 0.35,
                  child: Image.asset(
                    asset,
                    fit: isPlayer ? BoxFit.contain : BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      isPlayer ? Icons.person : Icons.shield_rounded,
                      size: 40,
                      color: borderColor,
                    ),
                  ),
                ),

                // Gold filigree edge
                CustomPaint(
                  painter: Aion2GoldFiligreePainter(
                    primaryGold: borderColor,
                    deepGold: const Color(0xFF8C6D23),
                    highlightGold: Colors.white,
                    cornerSize: 16,
                    showCrest: false,
                    showGems: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1424),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 0.8),
          ),
          child: Text(
            tag,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: borderColor,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}
