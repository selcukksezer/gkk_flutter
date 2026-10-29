import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Gladiator PvP Rank Tier classifications (Bronze to Abyssal Grandmaster).
enum GladiatorTier {
  bronze,
  silver,
  gold,
  platinum,
  diamond,
  master,
  grandmaster;

  static GladiatorTier fromRating(int rating) {
    if (rating >= 2100) return GladiatorTier.grandmaster;
    if (rating >= 1900) return GladiatorTier.master;
    if (rating >= 1700) return GladiatorTier.diamond;
    if (rating >= 1500) return GladiatorTier.platinum;
    if (rating >= 1300) return GladiatorTier.gold;
    if (rating >= 1100) return GladiatorTier.silver;
    return GladiatorTier.bronze;
  }

  String get title {
    switch (this) {
      case GladiatorTier.bronze:
        return 'Bronz Gladyatör';
      case GladiatorTier.silver:
        return 'Gümüş Gladyatör';
      case GladiatorTier.gold:
        return 'Altın Gladyatör';
      case GladiatorTier.platinum:
        return 'Platin Gladyatör';
      case GladiatorTier.diamond:
        return 'Elmas Gladyatör';
      case GladiatorTier.master:
        return 'Abyssal Efendisi';
      case GladiatorTier.grandmaster:
        return 'Abyssal Grandmaster';
    }
  }

  String get shortCode {
    switch (this) {
      case GladiatorTier.bronze:
        return 'BRONZE';
      case GladiatorTier.silver:
        return 'SILVER';
      case GladiatorTier.gold:
        return 'GOLD';
      case GladiatorTier.platinum:
        return 'PLATINUM';
      case GladiatorTier.diamond:
        return 'DIAMOND';
      case GladiatorTier.master:
        return 'MASTER';
      case GladiatorTier.grandmaster:
        return 'GRANDMASTER';
    }
  }

  int get minRating {
    switch (this) {
      case GladiatorTier.bronze:
        return 0;
      case GladiatorTier.silver:
        return 1100;
      case GladiatorTier.gold:
        return 1300;
      case GladiatorTier.platinum:
        return 1500;
      case GladiatorTier.diamond:
        return 1700;
      case GladiatorTier.master:
        return 1900;
      case GladiatorTier.grandmaster:
        return 2100;
    }
  }

  int get maxRating {
    switch (this) {
      case GladiatorTier.bronze:
        return 1099;
      case GladiatorTier.silver:
        return 1299;
      case GladiatorTier.gold:
        return 1499;
      case GladiatorTier.platinum:
        return 1699;
      case GladiatorTier.diamond:
        return 1899;
      case GladiatorTier.master:
        return 2099;
      case GladiatorTier.grandmaster:
        return 9999;
    }
  }

  Color get primaryColor {
    switch (this) {
      case GladiatorTier.bronze:
        return const Color(0xFFCD7F32);
      case GladiatorTier.silver:
        return const Color(0xFFC0C8D8);
      case GladiatorTier.gold:
        return const Color(0xFFFFD700);
      case GladiatorTier.platinum:
        return const Color(0xFF00E5FF);
      case GladiatorTier.diamond:
        return const Color(0xFFB388FF);
      case GladiatorTier.master:
        return const Color(0xFFFF1744);
      case GladiatorTier.grandmaster:
        return const Color(0xFFFF9100);
    }
  }

  Color get secondaryColor {
    switch (this) {
      case GladiatorTier.bronze:
        return const Color(0xFF8B5A2B);
      case GladiatorTier.silver:
        return const Color(0xFF7A8B9E);
      case GladiatorTier.gold:
        return const Color(0xFFB8860B);
      case GladiatorTier.platinum:
        return const Color(0xFF0097A7);
      case GladiatorTier.diamond:
        return const Color(0xFF7C4DFF);
      case GladiatorTier.master:
        return const Color(0xFF880E4F);
      case GladiatorTier.grandmaster:
        return const Color(0xFFFF1744);
    }
  }

  Color get glowColor {
    switch (this) {
      case GladiatorTier.bronze:
        return const Color(0x66CD7F32);
      case GladiatorTier.silver:
        return const Color(0x66C0C8D8);
      case GladiatorTier.gold:
        return const Color(0x88FFD700);
      case GladiatorTier.platinum:
        return const Color(0x8800E5FF);
      case GladiatorTier.diamond:
        return const Color(0x88B388FF);
      case GladiatorTier.master:
        return const Color(0x99FF1744);
      case GladiatorTier.grandmaster:
        return const Color(0xAAFF9100);
    }
  }

  IconData get iconData {
    switch (this) {
      case GladiatorTier.bronze:
        return Icons.shield_outlined;
      case GladiatorTier.silver:
        return Icons.shield_rounded;
      case GladiatorTier.gold:
        return Icons.military_tech_rounded;
      case GladiatorTier.platinum:
        return Icons.diamond_outlined;
      case GladiatorTier.diamond:
        return Icons.diamond_rounded;
      case GladiatorTier.master:
        return Icons.whatshot_rounded;
      case GladiatorTier.grandmaster:
        return Icons.auto_awesome_rounded;
    }
  }
}

/// Custom painter rendering AAA Aion-2 fantasy gladiator tier crests.
class GladiatorTierPainter extends CustomPainter {
  const GladiatorTierPainter({
    required this.tier,
    this.animationValue = 0.0,
    this.showGlow = true,
  });

  final GladiatorTier tier;
  final double animationValue;
  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);
    final double radius = math.min(w, h) / 2;

    // 1. Ambient Glow
    if (showGlow) {
      final Paint glowPaint = Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            tier.glowColor,
            tier.glowColor.withValues(alpha: 0.15),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.15));
      canvas.drawCircle(center, radius * 1.15, glowPaint);
    }

    // 2. Winged Mantle for Master & Grandmaster Tiers
    if (tier == GladiatorTier.master || tier == GladiatorTier.grandmaster) {
      final Paint wingPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            tier.primaryColor.withValues(alpha: 0.75),
            tier.secondaryColor.withValues(alpha: 0.35),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));

      // Left wing
      final Path leftWing = Path();
      leftWing.moveTo(center.dx - radius * 0.4, center.dy);
      leftWing.lineTo(center.dx - radius * 0.95, center.dy - radius * 0.55);
      leftWing.lineTo(center.dx - radius * 0.7, center.dy - radius * 0.15);
      leftWing.lineTo(center.dx - radius * 0.9, center.dy + radius * 0.2);
      leftWing.lineTo(center.dx - radius * 0.3, center.dy + radius * 0.4);
      leftWing.close();
      canvas.drawPath(leftWing, wingPaint);

      // Right wing
      final Path rightWing = Path();
      rightWing.moveTo(center.dx + radius * 0.4, center.dy);
      rightWing.lineTo(center.dx + radius * 0.95, center.dy - radius * 0.55);
      rightWing.lineTo(center.dx + radius * 0.7, center.dy - radius * 0.15);
      rightWing.lineTo(center.dx + radius * 0.9, center.dy + radius * 0.2);
      rightWing.lineTo(center.dx + radius * 0.3, center.dy + radius * 0.4);
      rightWing.close();
      canvas.drawPath(rightWing, wingPaint);
    }

    // 3. Main Shield Polygonal Geometry
    final Path shieldPath = Path();
    final double top = center.dy - radius * 0.75;
    final double bottom = center.dy + radius * 0.82;
    final double left = center.dx - radius * 0.68;
    final double right = center.dx + radius * 0.68;

    shieldPath.moveTo(center.dx, top - radius * 0.05);
    shieldPath.lineTo(right, top + radius * 0.2);
    shieldPath.lineTo(right - radius * 0.12, center.dy + radius * 0.25);
    shieldPath.lineTo(center.dx, bottom);
    shieldPath.lineTo(left + radius * 0.12, center.dy + radius * 0.25);
    shieldPath.lineTo(left, top + radius * 0.2);
    shieldPath.close();

    // Shield base metallic fill
    final Paint shieldFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          tier.primaryColor,
          tier.secondaryColor,
          const Color(0xFF0F1420),
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(shieldPath, shieldFill);

    // Inner facet shadow for chiseled metallic bevel
    final Path innerFacet = Path();
    innerFacet.moveTo(center.dx, top + radius * 0.05);
    innerFacet.lineTo(right - radius * 0.14, top + radius * 0.25);
    innerFacet.lineTo(right - radius * 0.24, center.dy + radius * 0.2);
    innerFacet.lineTo(center.dx, bottom - radius * 0.15);
    innerFacet.lineTo(left + radius * 0.24, center.dy + radius * 0.2);
    innerFacet.lineTo(left + radius * 0.14, top + radius * 0.25);
    innerFacet.close();

    final Paint innerFill = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          tier.primaryColor.withValues(alpha: 0.9),
          tier.secondaryColor.withValues(alpha: 0.7),
          const Color(0xFF0A0D16),
        ],
        stops: const <double>[0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.7));
    canvas.drawPath(innerFacet, innerFill);

    // Gold / Metal Trim Border
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.2, radius * 0.08)
      ..shader = SweepGradient(
        colors: <Color>[
          tier.primaryColor,
          Colors.white,
          tier.secondaryColor,
          tier.primaryColor,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.8));
    canvas.drawPath(shieldPath, borderPaint);

    // 4. Core Emblem Symbol / Gem
    final double gemRadius = radius * 0.25;
    final Path gemPath = Path();
    gemPath.moveTo(center.dx, center.dy - gemRadius * 1.2);
    gemPath.lineTo(center.dx + gemRadius, center.dy);
    gemPath.lineTo(center.dx, center.dy + gemRadius * 1.2);
    gemPath.lineTo(center.dx - gemRadius, center.dy);
    gemPath.close();

    final Paint gemPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white,
          tier.primaryColor,
          tier.secondaryColor,
        ],
        stops: const <double>[0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: gemRadius));
    canvas.drawPath(gemPath, gemPaint);

    // Gem highlight border
    final Paint gemBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawPath(gemPath, gemBorder);

    // 5. Grandmaster Rotating Astral Runic Halo
    if (tier == GladiatorTier.grandmaster) {
      final double haloRadius = radius * 0.9;
      final Paint haloPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = const Color(0xFFFFD54F).withValues(alpha: 0.6);
      canvas.drawCircle(center, haloRadius, haloPaint);

      final double rotation = animationValue * 2 * math.pi;
      final Paint starPaint = Paint()..color = Colors.white;
      for (int i = 0; i < 6; i++) {
        final double angle = (i * math.pi / 3) + rotation;
        final double px = center.dx + math.cos(angle) * haloRadius;
        final double py = center.dy + math.sin(angle) * haloRadius;
        canvas.drawCircle(Offset(px, py), 1.5, starPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GladiatorTierPainter oldDelegate) {
    return oldDelegate.tier != tier ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.showGlow != showGlow;
  }
}

/// Mobile Gladiator Tier Emblem Widget.
class GladiatorTierEmblem extends StatefulWidget {
  const GladiatorTierEmblem({
    super.key,
    this.tier,
    this.rating,
    this.size = 48.0,
    this.showLabel = false,
    this.showGlow = true,
    this.animated = true,
  });

  final GladiatorTier? tier;
  final int? rating;
  final double size;
  final bool showLabel;
  final bool showGlow;
  final bool animated;

  @override
  State<GladiatorTierEmblem> createState() => _GladiatorTierEmblemState();
}

class _GladiatorTierEmblemState extends State<GladiatorTierEmblem>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  GladiatorTier get effectiveTier {
    if (widget.tier != null) return widget.tier!;
    if (widget.rating != null) return GladiatorTier.fromRating(widget.rating!);
    return GladiatorTier.bronze;
  }

  @override
  void initState() {
    super.initState();
    if (widget.animated) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 4),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GladiatorTier tier = effectiveTier;

    Widget emblem = SizedBox(
      width: widget.size,
      height: widget.size,
      child: _controller != null
          ? AnimatedBuilder(
              animation: _controller!,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: GladiatorTierPainter(
                    tier: tier,
                    animationValue: _controller!.value,
                    showGlow: widget.showGlow,
                  ),
                );
              },
            )
          : CustomPaint(
              painter: GladiatorTierPainter(
                tier: tier,
                animationValue: 0.0,
                showGlow: widget.showGlow,
              ),
            ),
    );

    if (!widget.showLabel) {
      return emblem;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        emblem,
        const SizedBox(height: 4),
        Text(
          tier.title,
          style: TextStyle(
            color: tier.primaryColor,
            fontSize: (widget.size * 0.22).clamp(10.0, 14.0),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.rating != null)
          Text(
            '${widget.rating} MMR',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

/// Mobile OLED Progress Card for Gladiator MMR Rating and Tier Progression.
class GladiatorTierProgressCard extends StatelessWidget {
  const GladiatorTierProgressCard({
    super.key,
    required this.rating,
    this.pvpWins = 0,
    this.pvpLosses = 0,
    this.onViewLeaderboard,
  });

  final int rating;
  final int pvpWins;
  final int pvpLosses;
  final VoidCallback? onViewLeaderboard;

  @override
  Widget build(BuildContext context) {
    final GladiatorTier currentTier = GladiatorTier.fromRating(rating);
    final int nextTierMin = currentTier == GladiatorTier.grandmaster
        ? currentTier.minRating
        : currentTier.maxRating + 1;

    final int tierMin = currentTier.minRating;
    final int tierSpan = nextTierMin - tierMin;
    final double progress = currentTier == GladiatorTier.grandmaster
        ? 1.0
        : ((rating - tierMin) / (tierSpan > 0 ? tierSpan : 1)).clamp(0.0, 1.0);

    final int pointsToNext = nextTierMin - rating;
    final int totalMatches = pvpWins + pvpLosses;
    final String winRate = totalMatches > 0
        ? (pvpWins / totalMatches * 100).toStringAsFixed(1)
        : '0.0';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1523),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: currentTier.primaryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: currentTier.glowColor.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: Tier Title, Badge & Rank MMR
          Row(
            children: <Widget>[
              GladiatorTierEmblem(
                tier: currentTier,
                size: 52,
                showGlow: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: currentTier.primaryColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: currentTier.primaryColor.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            currentTier.shortCode,
                            style: TextStyle(
                              color: currentTier.primaryColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            currentTier.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Text(
                          '$rating MMR',
                          style: TextStyle(
                            color: currentTier.primaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '· Kazanma: %$winRate ($pvpWins G / $pvpLosses M)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onViewLeaderboard != null)
                IconButton(
                  onPressed: onViewLeaderboard,
                  icon: const Icon(Icons.leaderboard_rounded, color: Colors.amber, size: 20),
                  tooltip: 'Sıralama',
                ),
            ],
          ),

          const SizedBox(height: 12),

          // MMR Progress Bar towards Next Tier
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    currentTier == GladiatorTier.grandmaster
                        ? 'Zirve Rütbe (Apex Grandmaster)'
                        : 'Sonraki Aşama: +$pointsToNext MMR',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      color: currentTier.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 8,
                  child: Stack(
                    children: <Widget>[
                      Container(color: const Color(0xFF1B2336)),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                currentTier.secondaryColor,
                                currentTier.primaryColor,
                                Colors.white.withValues(alpha: 0.9),
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: currentTier.glowColor,
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
