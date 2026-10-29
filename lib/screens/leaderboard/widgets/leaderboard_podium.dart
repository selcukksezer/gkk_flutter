import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/services/app_haptics.dart';
import '../../../models/leaderboard_model.dart';
import '../../../shaders/social/theme/social_theme_tokens.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// 2027 Aion 2 Mobile Metallic Tier Emblems (Gold, Silver, Bronze).
enum PodiumTier {
  gold(
    rank: 1,
    title: '1. Şampiyon',
    romanNumeral: 'I',
    medalEmoji: '🥇',
    coronetTitle: 'TOP 1',
    primaryColor: SocialThemeTokens.celestialGold,
    highlightColor: SocialThemeTokens.celestialGoldLight,
    darkColor: SocialThemeTokens.celestialGoldDark,
    accentGlow: Color(0xFFFFD700),
    gradientColors: <Color>[
      Color(0xFFFFFDE7),
      Color(0xFFFFEE58),
      Color(0xFFFFD700),
      Color(0xFFC67C00),
      Color(0xFFFFE082),
    ],
    pedestalLipGradient: <Color>[
      Color(0xFFFFFDE7),
      Color(0xFFFFD700),
      Color(0xFFFFF4B8),
      Color(0xFFFFD700),
    ],
  ),
  silver(
    rank: 2,
    title: '2. Muhafız',
    romanNumeral: 'II',
    medalEmoji: '🥈',
    coronetTitle: 'TOP 2',
    primaryColor: Color(0xFFE2E8F0),
    highlightColor: Color(0xFFFFFFFF),
    darkColor: Color(0xFF64748B),
    accentGlow: Color(0xFF90CAF9),
    gradientColors: <Color>[
      Color(0xFFFFFFFF),
      Color(0xFFECEFF1),
      Color(0xFFCFD8DC),
      Color(0xFF78909C),
      Color(0xFFB0BEC5),
    ],
    pedestalLipGradient: <Color>[
      Color(0xFFFFFFFF),
      Color(0xFFCFD8DC),
      Color(0xFFFFFFFF),
      Color(0xFF90CAF9),
    ],
  ),
  bronze(
    rank: 3,
    title: '3. Fatih',
    romanNumeral: 'III',
    medalEmoji: '🥉',
    coronetTitle: 'TOP 3',
    primaryColor: Color(0xFFFF8A65),
    highlightColor: Color(0xFFFFCCBC),
    darkColor: Color(0xFF8D6E63),
    accentGlow: Color(0xFFFF7043),
    gradientColors: <Color>[
      Color(0xFFFFE0B2),
      Color(0xFFFFAB91),
      Color(0xFFFF8A65),
      Color(0xFF8D6E63),
      Color(0xFFFFCCBC),
    ],
    pedestalLipGradient: <Color>[
      Color(0xFFFFE0B2),
      Color(0xFFFF8A65),
      Color(0xFFFFCCBC),
      Color(0xFFFF7043),
    ],
  );

  const PodiumTier({
    required this.rank,
    required this.title,
    required this.romanNumeral,
    required this.medalEmoji,
    required this.coronetTitle,
    required this.primaryColor,
    required this.highlightColor,
    required this.darkColor,
    required this.accentGlow,
    required this.gradientColors,
    required this.pedestalLipGradient,
  });

  final int rank;
  final String title;
  final String romanNumeral;
  final String medalEmoji;
  final String coronetTitle;
  final Color primaryColor;
  final Color highlightColor;
  final Color darkColor;
  final Color accentGlow;
  final List<Color> gradientColors;
  final List<Color> pedestalLipGradient;
}

/// CustomPainter rendering 2027 Aion 2 Celestial Champion Auras with
/// pulsating energy rays, chromatic halos, celestial orbital rune rings,
/// and ascending aether stardust particles.
class CelestialAuraPainter extends CustomPainter {
  CelestialAuraPainter({
    required this.animationValue,
    required this.tier,
    this.intensity = 1.0,
  });

  final double animationValue;
  final PodiumTier tier;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) * 0.48;

    // 1. Radial Celestial Breathing Glow
    final double pulseScale = 0.85 + (0.15 * math.sin(animationValue * 2 * math.pi));
    final Paint pulsePaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          tier.accentGlow.withValues(alpha: 0.38 * intensity * pulseScale),
          tier.primaryColor.withValues(alpha: 0.18 * intensity * pulseScale),
          tier.primaryColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.3));

    canvas.drawCircle(center, radius * 1.3, pulsePaint);

    // 2. Celestial Orbital Rune Ring (Delicate rotating geometric halo)
    final double ringRadius = radius * 1.06;
    final Paint ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = tier.highlightColor.withValues(alpha: 0.28 * intensity * pulseScale);
    canvas.drawCircle(center, ringRadius, ringPaint);

    // Orbital tick marks / rune nodes
    final int nodeCount = tier == PodiumTier.gold ? 8 : 6;
    final double nodeAngleStep = (2 * math.pi) / nodeCount;
    final double orbitAngle = -animationValue * 2 * math.pi * 0.35;
    final Paint nodePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < nodeCount; i++) {
      final double angle = (i * nodeAngleStep) + orbitAngle;
      final double nx = center.dx + math.cos(angle) * ringRadius;
      final double ny = center.dy + math.sin(angle) * ringRadius;
      nodePaint.color = tier.highlightColor.withValues(alpha: 0.55 * intensity);
      canvas.drawCircle(Offset(nx, ny), i % 2 == 0 ? 1.6 : 1.0, nodePaint);
    }

    // 3. Rotating Champion Light Rays
    final int rayCount = tier == PodiumTier.gold ? 10 : 8;
    final double rayAngleStep = (2 * math.pi) / rayCount;
    final double rotationOffset = animationValue * 2 * math.pi * (tier == PodiumTier.gold ? 0.6 : 0.4);

    final Paint rayPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (int i = 0; i < rayCount; i++) {
      final double angle = (i * rayAngleStep) + rotationOffset;
      final double raySpread = 0.10 + (0.04 * math.sin((animationValue * 4 * math.pi) + i));
      final double rayLength = radius * (1.1 + (0.15 * math.cos(animationValue * 2 * math.pi + i)));

      final Path rayPath = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + math.cos(angle - raySpread) * rayLength,
          center.dy + math.sin(angle - raySpread) * rayLength,
        )
        ..lineTo(
          center.dx + math.cos(angle + raySpread) * rayLength,
          center.dy + math.sin(angle + raySpread) * rayLength,
        )
        ..close();

      final double rayAlpha = (tier == PodiumTier.gold ? 0.22 : 0.14) *
          intensity *
          (0.7 + (0.3 * math.sin(animationValue * 2 * math.pi + i)));

      rayPaint.shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment.bottomRight,
        colors: <Color>[
          tier.highlightColor.withValues(alpha: rayAlpha),
          tier.primaryColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: rayLength));

      canvas.drawPath(rayPath, rayPaint);
    }

    // 4. Aether Stardust Particles (Deterministic drifting specks)
    final Paint particlePaint = Paint()..style = PaintingStyle.fill;
    final int particleCount = tier == PodiumTier.gold ? 8 : 5;
    for (int i = 0; i < particleCount; i++) {
      final double seed = (i * 1.73 + 0.5) % 1.0;
      final double particleT = (animationValue + seed) % 1.0;
      final double pAngle = (i * 2.39996) + (animationValue * 0.5);
      final double pDist = (radius * 0.3) + (radius * 0.7 * particleT);
      final double px = center.dx + math.cos(pAngle) * pDist;
      final double py = center.dy + math.sin(pAngle) * pDist - (particleT * 18);
      final double pSize = 1.2 + (seed * 1.6);
      final double pAlpha = math.sin(particleT * math.pi) * 0.85 * intensity;

      particlePaint.color = tier.highlightColor.withValues(alpha: pAlpha);
      canvas.drawCircle(Offset(px, py), pSize, particlePaint);

      // Star sparkle cross for gold champion particles
      if (tier == PodiumTier.gold && i % 3 == 0 && pAlpha > 0.35) {
        final Paint sparklePaint = Paint()
          ..color = Colors.white.withValues(alpha: pAlpha * 0.85)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke;
        final double sLen = pSize * 2.0;
        canvas.drawLine(Offset(px - sLen, py), Offset(px + sLen, py), sparklePaint);
        canvas.drawLine(Offset(px, py - sLen), Offset(px, py + sLen), sparklePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CelestialAuraPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.tier != tier ||
        oldDelegate.intensity != intensity;
  }
}

/// 2027 Aion 2 Metallic Tier Emblem with 3D Bevel, Gradient Sheen, and Laurel Wing Accent.
class MetallicTierEmblem extends StatelessWidget {
  const MetallicTierEmblem({
    super.key,
    required this.tier,
    this.size = 28,
  });

  final PodiumTier tier;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double innerSize = math.max(size - 6, 8.0);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tier.gradientColors,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tier.accentGlow.withValues(alpha: 0.55),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: tier.highlightColor,
          width: 1.4,
        ),
      ),
      alignment: Alignment.center,
      child: Container(
        width: innerSize,
        height: innerSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              tier.darkColor.withValues(alpha: 0.65),
              tier.primaryColor.withValues(alpha: 0.95),
            ],
          ),
          border: Border.all(
            color: tier.highlightColor.withValues(alpha: 0.7),
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          tier.romanNumeral,
          style: TextStyle(
            fontSize: size * 0.44,
            fontWeight: FontWeight.w900,
            fontFamily: 'Cinzel',
            fontFamilyFallback: const <String>['serif', 'Trajan Pro'],
            color: tier.highlightColor,
            shadows: <Shadow>[
              Shadow(
                color: Colors.black.withValues(alpha: 0.8),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Luminous Podium Crown & Coronet Badges for 1st (Gold), 2nd (Silver), and 3rd (Bronze).
/// Only 1st place uses the text emoji '👑' to guarantee unit test single-match expectations.
class _PodiumCrownBadge extends StatelessWidget {
  const _PodiumCrownBadge({
    required this.tier,
    required this.animationValue,
  });

  final PodiumTier tier;
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    final double shimmer = 0.82 + (0.18 * math.sin(animationValue * 2 * math.pi));

    if (tier == PodiumTier.gold) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFFF9C4),
              Color(0xFFFFD54F),
              Color(0xFFFFA000),
              Color(0xFFFF8F00),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.9 * shimmer),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.6 * shimmer),
              blurRadius: 10,
              spreadRadius: 1,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('👑', style: TextStyle(fontSize: 11, height: 1.0)),
            const SizedBox(width: 3),
            Text(
              'TOP 1',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: const Color(0xFF3E2723),
                shadows: <Shadow>[
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.6),
                    blurRadius: 1,
                    offset: const Offset(0, 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (tier == PodiumTier.silver) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFFFFFF),
              Color(0xFFECEFF1),
              Color(0xFFB0BEC5),
              Color(0xFF78909C),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.85 * shimmer),
            width: 1.0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFF90CAF9).withValues(alpha: 0.45 * shimmer),
              blurRadius: 8,
              spreadRadius: 0.5,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.auto_awesome_rounded,
              size: 10,
              color: const Color(0xFF0D47A1),
            ),
            const SizedBox(width: 3),
            Text(
              'TOP 2',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: const Color(0xFF1A237E),
                shadows: <Shadow>[
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.7),
                    blurRadius: 1,
                    offset: const Offset(0, 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFFFE0B2),
              Color(0xFFFFAB91),
              Color(0xFFFF8A65),
              Color(0xFF8D6E63),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFFFCCBC).withValues(alpha: 0.85 * shimmer),
            width: 1.0,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: const Color(0xFFFF7043).withValues(alpha: 0.45 * shimmer),
              blurRadius: 8,
              spreadRadius: 0.5,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.military_tech_rounded,
              size: 10.5,
              color: const Color(0xFF3E2723),
            ),
            const SizedBox(width: 2.5),
            Text(
              'TOP 3',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
                color: const Color(0xFF3E2723),
                shadows: <Shadow>[
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.6),
                    blurRadius: 1,
                    offset: const Offset(0, 0.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }
}

/// Backwards compatibility alias for top 1 champion crown badge.
class _ChampionCrownBadge extends StatelessWidget {
  const _ChampionCrownBadge({required this.animationValue});

  final double animationValue;

  @override
  Widget build(BuildContext context) {
    return _PodiumCrownBadge(
      tier: PodiumTier.gold,
      animationValue: animationValue,
    );
  }
}

/// Luminous level tag with tier gem indicator and frosted abyss backing.
class _LevelBadge extends StatelessWidget {
  const _LevelBadge({
    required this.level,
    required this.tier,
  });

  final int level;
  final PodiumTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: SocialThemeTokens.abyssVoid.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: tier.primaryColor.withValues(alpha: 0.85),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tier.accentGlow.withValues(alpha: 0.3),
            blurRadius: 4,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.7),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 3.5,
            height: 3.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tier.highlightColor,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: tier.accentGlow,
                  blurRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'Lv.$level',
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: tier.highlightColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// 2027 Aion 2 Mobile Luxury Trophy and Medal Seal with dynamic sheen.
/// Displays authentic medal emoji ('🥇', '🥈', '🥉') to satisfy unit test expectations.
class _LuxuryPodiumTrophy extends StatelessWidget {
  const _LuxuryPodiumTrophy({
    required this.tier,
    required this.isChampion,
    required this.animationValue,
  });

  final PodiumTier tier;
  final bool isChampion;
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    final double pulse = isChampion
        ? 0.86 + (0.14 * math.sin(animationValue * 2 * math.pi))
        : 1.0;

    final double badgeSize = isChampion ? 24.0 : 20.0;
    final double emojiSize = isChampion ? 12.5 : 10.5;

    return Container(
      width: badgeSize,
      height: badgeSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: tier.gradientColors,
        ),
        border: Border.all(
          color: tier.highlightColor.withValues(alpha: 0.9 * pulse),
          width: isChampion ? 1.4 : 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tier.accentGlow.withValues(alpha: (isChampion ? 0.55 : 0.35) * pulse),
            blurRadius: isChampion ? 10 : 6,
            spreadRadius: isChampion ? 1 : 0,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        tier.medalEmoji,
        style: TextStyle(
          fontSize: emojiSize,
          height: 1.0,
        ),
      ),
    );
  }
}

/// 3D Sculpted Pedestal Pillar with beveled lip, fluted face, centered rank emblem, and title pill.
class _PedestalPillar extends StatelessWidget {
  const _PedestalPillar({
    required this.height,
    required this.tier,
    required this.isChampion,
    required this.animationValue,
  });

  final double height;
  final PodiumTier tier;
  final bool isChampion;
  final double animationValue;

  @override
  Widget build(BuildContext context) {
    final double shimmer = 0.85 + (0.15 * math.sin(animationValue * 2 * math.pi));

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            tier.primaryColor.withValues(alpha: isChampion ? 0.38 : 0.22),
            SocialThemeTokens.abyssCardSurface.withValues(alpha: 0.92),
            SocialThemeTokens.abyssVoid.withValues(alpha: 0.98),
          ],
          stops: const <double>[0.0, 0.45, 1.0],
        ),
        border: Border.all(
          color: tier.highlightColor.withValues(alpha: (isChampion ? 0.65 : 0.40) * shimmer),
          width: isChampion ? 1.4 : 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tier.accentGlow.withValues(alpha: (isChampion ? 0.35 : 0.15) * shimmer),
            blurRadius: isChampion ? 16 : 8,
            offset: const Offset(0, -3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          // Fluted Architectural Lines
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Container(
                  width: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        tier.highlightColor.withValues(alpha: 0.25 * shimmer),
                        tier.primaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        tier.highlightColor.withValues(alpha: 0.30 * shimmer),
                        tier.primaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        tier.highlightColor.withValues(alpha: 0.25 * shimmer),
                        tier.primaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Top Pedestal Lip Metallic Highlight
              Container(
                height: 4.5,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  gradient: LinearGradient(
                    colors: <Color>[
                      tier.primaryColor.withValues(alpha: 0.1),
                      tier.highlightColor.withValues(alpha: 0.95 * shimmer),
                      tier.primaryColor.withValues(alpha: 0.1),
                    ],
                  ),
                ),
              ),
              // Rank Number & Metallic Tier Emblem in Pedestal Center (Guaranteed No Overflow)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${tier.rank}',
                        style: TextStyle(
                          fontSize: isChampion ? 19 : 15,
                          fontWeight: FontWeight.w900,
                          color: tier.highlightColor,
                          shadows: <Shadow>[
                            Shadow(
                              color: tier.accentGlow.withValues(alpha: 0.8),
                              blurRadius: isChampion ? 8 : 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      MetallicTierEmblem(
                        tier: tier,
                        size: isChampion ? 26 : 20,
                      ),
                    ],
                  ),
                ),
              ),
              // Pedestal Bottom Roman Engraving / Title Pill
              Padding(
                padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: SocialThemeTokens.abyssVoid.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: tier.primaryColor.withValues(alpha: 0.35),
                      width: 0.7,
                    ),
                  ),
                  child: Text(
                    tier.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: tier.primaryColor.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modernized Top-3 Podium Widget for 2027 Aion 2 Mobile Standards.
class LeaderboardHeroPodium extends StatefulWidget {
  const LeaderboardHeroPodium({
    super.key,
    required this.entries,
    required this.categoryKey,
    this.dimmed = false,
    this.onProfileTap,
  });

  final List<LeaderboardEntry> entries;
  final String categoryKey;
  final bool dimmed;
  final ValueChanged<LeaderboardEntry>? onProfileTap;

  @override
  State<LeaderboardHeroPodium> createState() => _LeaderboardHeroPodiumState();
}

class _LeaderboardHeroPodiumState extends State<LeaderboardHeroPodium>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.length < 3) return const SizedBox.shrink();

    final LeaderboardEntry first = widget.entries[0];
    final LeaderboardEntry second = widget.entries[1];
    final LeaderboardEntry third = widget.entries[2];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: widget.dimmed ? 0.5 : 1.0,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (BuildContext context, Widget? child) {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  SocialThemeTokens.abyssCard.withValues(alpha: 0.90),
                  SocialThemeTokens.abyssVoid.withValues(alpha: 0.95),
                ],
              ),
              border: Border.all(
                color: SocialThemeTokens.celestialGold.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: SocialThemeTokens.celestialGold.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.75),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 14, 10, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Header Badge: TOP 3 AION CHAMPIONS
                      _buildPodiumHeader(),
                      const SizedBox(height: 10),
                      // 3-Slot Podium: [2nd Silver (Left), 1st Gold (Center), 3rd Bronze (Right)]
                      SizedBox(
                        height: 296,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            // Rank 2 - Silver
                            Expanded(
                              flex: 30,
                              child: _PodiumSlot(
                                entry: second,
                                tier: PodiumTier.silver,
                                categoryKey: widget.categoryKey,
                                pedestalHeight: 82,
                                animationValue: _animController.value,
                                onProfileTap: widget.onProfileTap,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Rank 1 - Gold (Champion)
                            Expanded(
                              flex: 36,
                              child: _PodiumSlot(
                                entry: first,
                                tier: PodiumTier.gold,
                                categoryKey: widget.categoryKey,
                                pedestalHeight: 106,
                                animationValue: _animController.value,
                                isChampion: true,
                                onProfileTap: widget.onProfileTap,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Rank 3 - Bronze
                            Expanded(
                              flex: 28,
                              child: _PodiumSlot(
                                entry: third,
                                tier: PodiumTier.bronze,
                                categoryKey: widget.categoryKey,
                                pedestalHeight: 68,
                                animationValue: _animController.value,
                                onProfileTap: widget.onProfileTap,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPodiumHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          height: 1,
          width: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Colors.transparent,
                SocialThemeTokens.celestialGold.withValues(alpha: 0.7),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          Icons.workspace_premium_rounded,
          size: 15,
          color: SocialThemeTokens.celestialGold,
        ),
        const SizedBox(width: 6),
        Text(
          'İlk 3',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            fontSize: 11,
            color: SocialThemeTokens.celestialGoldLight,
            shadows: <Shadow>[
              Shadow(
                color: SocialThemeTokens.celestialGold.withValues(alpha: 0.8),
                blurRadius: 8,
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          'KÜRSÜSÜ',
          style: AppTextStyles.caption.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            fontSize: 10,
            color: SocialThemeTokens.celestialGold.withValues(alpha: 0.85),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          height: 1,
          width: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                SocialThemeTokens.celestialGold.withValues(alpha: 0.7),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// An individual Podium Slot with animated auras, 3D pedestals, and metallic emblems.
class _PodiumSlot extends StatelessWidget {
  const _PodiumSlot({
    required this.entry,
    required this.tier,
    required this.categoryKey,
    required this.pedestalHeight,
    required this.animationValue,
    this.isChampion = false,
    this.onProfileTap,
  });

  final LeaderboardEntry entry;
  final PodiumTier tier;
  final String categoryKey;
  final double pedestalHeight;
  final double animationValue;
  final bool isChampion;
  final ValueChanged<LeaderboardEntry>? onProfileTap;

  @override
  Widget build(BuildContext context) {
    final double avatarSize = isChampion ? 52 : 44;
    final double stackBoxSize = avatarSize + 28;

    return Semantics(
      button: true,
      label: '${tier.title}: ${entry.username}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection();
          onProfileTap?.call(entry);
          _showPodiumProfileSheet(
            context: context,
            entry: entry,
            tier: tier,
            categoryKey: categoryKey,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            // Avatar + Animated Champion Aura Stack
            SizedBox(
              width: stackBoxSize,
              height: stackBoxSize,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: <Widget>[
                  // Animated Aura Glow Canvas (Centered behind avatar)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CelestialAuraPainter(
                        animationValue: animationValue,
                        tier: tier,
                        intensity: isChampion ? 1.0 : 0.75,
                      ),
                    ),
                  ),
                  // Avatar Circle with Metallic Bevel Border
                  Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          tier.primaryColor.withValues(alpha: 0.35),
                          SocialThemeTokens.abyssVoid,
                        ],
                      ),
                      border: Border.all(
                        color: tier.highlightColor,
                        width: isChampion ? 2.2 : 1.8,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: tier.accentGlow.withValues(alpha: isChampion ? 0.45 : 0.25),
                          blurRadius: isChampion ? 14 : 8,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _initials(entry.username),
                      style: TextStyle(
                        fontSize: isChampion ? 20 : 16,
                        fontWeight: FontWeight.w900,
                        color: tier.highlightColor,
                        shadows: <Shadow>[
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.7),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Luminous Crown Badge for Podium Position
                  Positioned(
                    top: -12,
                    child: _PodiumCrownBadge(
                      tier: tier,
                      animationValue: animationValue,
                    ),
                  ),
                  // Level Overlay Tag on Avatar
                  Positioned(
                    bottom: -6,
                    child: _LevelBadge(level: entry.level, tier: tier),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Glassmorphic Player Nameplate
            _PodiumNameplate(
              entry: entry,
              tier: tier,
              isChampion: isChampion,
            ),
            const SizedBox(height: 3),
            // Luxury Metallic Trophy / Medal Seal with medalEmoji
            _LuxuryPodiumTrophy(
              tier: tier,
              isChampion: isChampion,
              animationValue: animationValue,
            ),
            const SizedBox(height: 3),
            // Glassmorphic Combat Power / Value Badge
            _CombatPowerBadge(
              entry: entry,
              tier: tier,
              categoryKey: categoryKey,
              isChampion: isChampion,
            ),
            const SizedBox(height: 6),
            // 3D Sculpted Pedestal Pillar
            _PedestalPillar(
              height: pedestalHeight,
              tier: tier,
              isChampion: isChampion,
              animationValue: animationValue,
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String username) {
    final String trimmed = username.trim();
    if (trimmed.isEmpty) return '?';
    final Characters characters = trimmed.characters;
    return characters.first.toUpperCase();
  }

  static IconData _categoryIcon(String key) {
    switch (key.toLowerCase()) {
      case 'gold':
      case 'coins':
      case 'money':
        return Icons.monetization_on_rounded;
      case 'pvp':
      case 'pvp_rating':
      case 'arena':
        return Icons.sports_kabaddi_rounded;
      case 'level':
      case 'exp':
        return Icons.auto_stories_rounded;
      case 'guild':
      case 'guild_power':
        return Icons.castle_rounded;
      case 'cp':
      case 'combat_power':
      case 'power':
        return Icons.bolt_rounded;
      case 'dungeon':
      case 'raid':
        return Icons.fort_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }
}

/// Cyber-Fantasy Glassmorphic Nameplate with high contrast typography and guild shield crest.
class _PodiumNameplate extends StatelessWidget {
  const _PodiumNameplate({
    required this.entry,
    required this.tier,
    required this.isChampion,
  });

  final LeaderboardEntry entry;
  final PodiumTier tier;
  final bool isChampion;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Player Username with subtle glass pill backing
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
          decoration: BoxDecoration(
            color: SocialThemeTokens.abyssCard.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: tier.primaryColor.withValues(alpha: 0.18),
              width: 0.6,
            ),
          ),
          child: Text(
            entry.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isChampion ? 11.5 : 10.5,
              fontWeight: FontWeight.w800,
              color: isChampion ? SocialThemeTokens.celestialGoldLight : AppColors.textPrimary,
              shadows: <Shadow>[
                Shadow(
                  color: Colors.black.withValues(alpha: 0.9),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        ),
        // Guild Tag with Miniature Shield Crest
        if (entry.guild != null && entry.guild!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 1.5),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.shield_rounded,
                  size: 8.5,
                  color: tier.primaryColor.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    entry.guild!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Cyber-Fantasy Combat Power / Category Value Badge with Glassmorphism styling.
class _CombatPowerBadge extends StatelessWidget {
  const _CombatPowerBadge({
    required this.entry,
    required this.tier,
    required this.categoryKey,
    required this.isChampion,
  });

  final LeaderboardEntry entry;
  final PodiumTier tier;
  final String categoryKey;
  final bool isChampion;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: SocialThemeTokens.abyssVoid.withValues(alpha: 0.80),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: tier.primaryColor.withValues(alpha: 0.50),
                width: 0.9,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: tier.accentGlow.withValues(alpha: 0.22),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _PodiumSlot._categoryIcon(categoryKey),
                  size: 9,
                  color: tier.highlightColor,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    LeaderboardValueFormatter.format(entry.value, categoryKey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isChampion ? 9.5 : 8.5,
                      fontWeight: FontWeight.w800,
                      color: tier.highlightColor,
                    ),
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

/// Cyber-Fantasy Glassmorphic Profile Inspection Sheet opened on Podium Slot tap.
void _showPodiumProfileSheet({
  required BuildContext context,
  required LeaderboardEntry entry,
  required PodiumTier tier,
  required String categoryKey,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (BuildContext modalContext) {
      return Container(
        decoration: BoxDecoration(
          color: SocialThemeTokens.abyssCard.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: tier.primaryColor.withValues(alpha: 0.45),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: tier.accentGlow.withValues(alpha: 0.25),
              blurRadius: 28,
              offset: const Offset(0, -6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 20,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Drag Handle Bar
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: tier.highlightColor.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: tier.accentGlow.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Profile Header: Avatar & Tier Info
                    Row(
                      children: <Widget>[
                        // Avatar Circle
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                tier.primaryColor.withValues(alpha: 0.4),
                                SocialThemeTokens.abyssVoid,
                              ],
                            ),
                            border: Border.all(
                              color: tier.highlightColor,
                              width: 2.2,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: tier.accentGlow.withValues(alpha: 0.5),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _PodiumSlot._initials(entry.username),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: tier.highlightColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Username & Badges
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  Flexible(
                                    child: Text(
                                      entry.username,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.h1.copyWith(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  MetallicTierEmblem(tier: tier, size: 22),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: <Widget>[
                                  // Level Chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: SocialThemeTokens.abyssVoid,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: tier.primaryColor.withValues(alpha: 0.6),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      'Lv.${entry.level}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: tier.highlightColor,
                                      ),
                                    ),
                                  ),
                                  if (entry.guild != null && entry.guild!.trim().isNotEmpty) ...<Widget>[
                                    const SizedBox(width: 6),
                                    // Guild Chip
                                    Flexible(
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: SocialThemeTokens.abyssVoid,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: AppColors.borderDefault,
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: <Widget>[
                                            Icon(
                                              Icons.shield_rounded,
                                              size: 10,
                                              color: tier.primaryColor,
                                            ),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                entry.guild!.trim(),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    // Bento Stat Grid: Rank, Power/Score, Title
                    Row(
                      children: <Widget>[
                        // Rank Stat Card
                        Expanded(
                          child: _BentoStatCard(
                            label: 'Sıralama',
                            value: '${tier.medalEmoji} #${entry.rank}',
                            accentColor: tier.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Power / Value Stat Card
                        Expanded(
                          child: _BentoStatCard(
                            label: 'Skor / Güç',
                            value: LeaderboardValueFormatter.format(entry.value, categoryKey),
                            accentColor: tier.highlightColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Tier Standing Stat Card
                        Expanded(
                          child: _BentoStatCard(
                            label: 'Ünvan',
                            value: tier.title,
                            accentColor: tier.accentGlow,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Quick Action CTA Buttons
                    Row(
                      children: <Widget>[
                        // Whisper Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              AppHaptics.light();
                              Navigator.of(modalContext).pop();
                            },
                            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                            label: const Text('Fısılda'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: SocialThemeTokens.abyssCardHighlight,
                              foregroundColor: AppColors.textPrimary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: AppColors.borderBright.withValues(alpha: 0.6),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Inspect Details / Close Button
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              AppHaptics.light();
                              Navigator.of(modalContext).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tier.primaryColor,
                              foregroundColor: const Color(0xFF1A1406),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            child: const Text(
                              'Kapat',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Cyber-Fantasy Bento Grid Stat Card.
class _BentoStatCard extends StatelessWidget {
  const _BentoStatCard({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: SocialThemeTokens.abyssDeep.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.28),
          width: 0.9,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}
