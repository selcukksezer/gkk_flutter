import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import 'faction_crest_painter.dart';

/// Fluttering dark fantasy banner cloth painter with sinusoidal wind deformation.
class BannerClothPainter extends CustomPainter {
  BannerClothPainter({
    required this.faction,
    required this.waveProgress,
  });

  final FactionType faction;
  final double waveProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Cloth silhouette with notched swallowtail bottom
    final Path path = Path();
    path.moveTo(0, 0);
    path.lineTo(w, 0);

    // Right side with subtle wind wave
    final double waveAmp = 3.0;
    final double rightWave = math.sin(waveProgress * 2 * math.pi) * waveAmp;
    path.lineTo(w + rightWave, h - 16);

    // V-cut swallowtail bottom
    path.lineTo(w * 0.5, h - 30 + rightWave * 0.5);
    path.lineTo(0, h - 16);
    path.close();

    final Color topColor = faction == FactionType.elyos
        ? const Color(0xFF2A2208)
        : const Color(0xFF240A12);
    final Color bottomColor = faction == FactionType.elyos
        ? const Color(0xFF131006)
        : const Color(0xFF140509);

    final Paint clothPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[topColor, bottomColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, clothPaint);

    // Border trim (Gold for Elyos, Obsidian Crimson for Asmodian)
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: faction == FactionType.elyos
            ? const <Color>[Color(0xFFFFD54F), Color(0xFFFFA000), Color(0xFF5D4037)]
            : const <Color>[Color(0xFFFF5252), Color(0xFFB71C1C), Color(0xFF212121)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(path, borderPaint);

    // Top horizontal crossbar / hanging rod
    final Paint rodPaint = Paint()
      ..color = faction == FactionType.elyos ? const Color(0xFFFFD700) : const Color(0xFFFF5252)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-4, 0), Offset(w + 4, 0), rodPaint);
  }

  @override
  bool shouldRepaint(covariant BannerClothPainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress || oldDelegate.faction != faction;
  }
}

/// Animated Faction War Banner representing either Elyos or Asmodian faction allegiance.
class FactionWarBanner extends StatefulWidget {
  const FactionWarBanner({
    super.key,
    required this.faction,
    this.title,
    this.subtitle,
    this.height = 140.0,
    this.width,
    this.isCompact = false,
  });

  final FactionType faction;
  final String? title;
  final String? subtitle;
  final double height;
  final double? width;
  final bool isCompact;

  @override
  State<FactionWarBanner> createState() => _FactionWarBannerState();
}

class _FactionWarBannerState extends State<FactionWarBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isElyos = widget.faction == FactionType.elyos;
    final String defaultTitle = isElyos ? 'ELYOS' : 'ASMODIAN';
    final String defaultSub = isElyos ? 'Işığın Egemenliği' : 'Gölge Lejyonu';

    final double bannerWidth = widget.width ?? (widget.isCompact ? 90 : 130);

    return AnimatedBuilder(
      animation: _anim,
      builder: (BuildContext context, Widget? child) {
        return SizedBox(
          width: bannerWidth,
          height: widget.height,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: <Widget>[
              // 1. Fluttering Cloth
              Positioned.fill(
                child: CustomPaint(
                  painter: BannerClothPainter(
                    faction: widget.faction,
                    waveProgress: _anim.value,
                  ),
                ),
              ),

              // 2. Banner Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FactionCrestWidget(
                      faction: widget.faction,
                      size: widget.isCompact ? 38 : 50,
                      showGlow: true,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.title ?? defaultTitle,
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        fontWeight: FontWeight.w900,
                        fontSize: widget.isCompact ? 10 : 12,
                        letterSpacing: 1.5,
                        color: widget.faction.primaryColor,
                        shadows: <Shadow>[
                          Shadow(
                            color: widget.faction.glowColor.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!widget.isCompact) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle ?? defaultSub,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Dynamic Clash Collision painter rendering lightning arcs between opposing factions.
class ClashCollisionPainter extends CustomPainter {
  ClashCollisionPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Glowing energy clash sphere
    final Paint spherePaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white,
          AppColors.liquidGold.withValues(alpha: 0.8),
          AppColors.mysticRuby.withValues(alpha: 0.6),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.25, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 24));

    canvas.drawCircle(Offset(cx, cy), 20, spherePaint);

    // Electric collision bolts
    final Paint boltPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final math.Random rng = math.Random((progress * 100).toInt());
    for (int i = 0; i < 4; i++) {
      final Path bolt = Path();
      bolt.moveTo(cx - 12 + rng.nextDouble() * 4, cy - 10 + rng.nextDouble() * 20);
      bolt.lineTo(cx + rng.nextDouble() * 6 - 3, cy + rng.nextDouble() * 6 - 3);
      bolt.lineTo(cx + 12 - rng.nextDouble() * 4, cy - 10 + rng.nextDouble() * 20);
      canvas.drawPath(bolt, boltPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ClashCollisionPainter oldDelegate) => true;
}

/// Faction Clash Banner displaying Elyos vs Asmodian confrontation with live score & territory control ratio.
class FactionClashBanner extends StatefulWidget {
  const FactionClashBanner({
    super.key,
    this.elyosScore = 1420,
    this.asmodianScore = 1380,
    this.elyosTerritoryCount = 4,
    this.asmodianTerritoryCount = 3,
    this.battleTimerText = '14:28',
    this.onTap,
  });

  final int elyosScore;
  final int asmodianScore;
  final int elyosTerritoryCount;
  final int asmodianTerritoryCount;
  final String battleTimerText;
  final VoidCallback? onTap;

  @override
  State<FactionClashBanner> createState() => _FactionClashBannerState();
}

class _FactionClashBannerState extends State<FactionClashBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _clashAnim;

  @override
  void initState() {
    super.initState();
    _clashAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _clashAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int total = (widget.elyosScore + widget.asmodianScore).clamp(1, 1 << 30);
    final double ratio = (widget.elyosScore / total).clamp(0.05, 0.95);

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF1A140A), // Warm gold-dark
              Color(0xFF0F121C),
              Color(0xFF1C0A10), // Warm ruby-dark
            ],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Header Row: Battle Mode & Timer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.toxicNeon,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'HAKİMİYET SAVAŞI · CANLI',
                      style: TextStyle(
                        color: AppColors.toxicNeon,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.timer_outlined, size: 12, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        widget.battleTimerText,
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Confrontation Row: Elyos vs Asmodian
            Row(
              children: <Widget>[
                // Left: Elyos Faction
                Expanded(
                  child: Row(
                    children: <Widget>[
                      const FactionCrestWidget(
                        faction: FactionType.elyos,
                        size: 40,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'ELYOS',
                              style: TextStyle(
                                color: AppColors.liquidGold,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${widget.elyosScore} Puan · ${widget.elyosTerritoryCount} Bölge',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Center: Animated Collision Nexus
                AnimatedBuilder(
                  animation: _clashAnim,
                  builder: (BuildContext context, Widget? child) {
                    return SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          CustomPaint(
                            size: const Size(44, 44),
                            painter: ClashCollisionPainter(
                              progress: _clashAnim.value,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF12141F),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.6),
                                width: 1.2,
                              ),
                            ),
                            child: const Text(
                              'VS',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Right: Asmodian Faction
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            const Text(
                              'ASMODIAN',
                              style: TextStyle(
                                color: AppColors.mysticRuby,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 1.0,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${widget.asmodianScore} Puan · ${widget.asmodianTerritoryCount} Bölge',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const FactionCrestWidget(
                        faction: FactionType.asmodian,
                        size: 40,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Tug of War Territory Control Ratio Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 6,
                child: Row(
                  children: <Widget>[
                    Flexible(
                      flex: (ratio * 1000).toInt(),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[Color(0xFFFFD54F), Color(0xFFFF8F00)],
                          ),
                        ),
                      ),
                    ),
                    Container(width: 2, color: Colors.white),
                    Flexible(
                      flex: ((1.0 - ratio) * 1000).toInt(),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[Color(0xFFD50000), Color(0xFF6A1B9A)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AAA Mobile Guild War Room Banner with animated heraldry and gold metallic trim.
class GuildWarRoomBanner extends StatefulWidget {
  const GuildWarRoomBanner({
    super.key,
    required this.guildName,
    this.faction = FactionType.neutral,
    this.symbol = GuildCrestSymbol.dragon,
    this.primaryColor = AppColors.liquidGold,
    this.secondaryColor = const Color(0xFF8D6E63),
    this.rankBadge,
    this.points,
    this.height = 160.0,
    this.onTap,
  });

  final String guildName;
  final FactionType faction;
  final GuildCrestSymbol symbol;
  final Color primaryColor;
  final Color secondaryColor;
  final String? rankBadge;
  final int? points;
  final double height;
  final VoidCallback? onTap;

  @override
  State<GuildWarRoomBanner> createState() => _GuildWarRoomBannerState();
}

class _GuildWarRoomBannerState extends State<GuildWarRoomBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveAnim;

  @override
  void initState() {
    super.initState();
    _waveAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();
  }

  @override
  void dispose() {
    _waveAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _waveAnim,
        builder: (BuildContext context, Widget? child) {
          return SizedBox(
            height: widget.height,
            child: Stack(
              alignment: Alignment.topCenter,
              children: <Widget>[
                // 1. Fluttering Cloth Silhouette
                Positioned.fill(
                  child: CustomPaint(
                    painter: BannerClothPainter(
                      faction: widget.faction,
                      waveProgress: _waveAnim.value,
                    ),
                  ),
                ),

                // 2. Banner Content & Heraldry
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Guild Custom Crest Emblem
                      GuildCustomCrestWidget(
                        symbol: widget.symbol,
                        primaryColor: widget.primaryColor,
                        secondaryColor: widget.secondaryColor,
                        faction: widget.faction,
                        size: 44,
                      ),
                      const SizedBox(height: 6),

                      // Guild Name with gold metallic glow
                      Text(
                        widget.guildName,
                        style: const TextStyle(
                          fontFamily: 'Cinzel',
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 1.0,
                          shadows: <Shadow>[
                            Shadow(color: AppColors.liquidGold, blurRadius: 8),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),

                      if (widget.rankBadge != null || widget.points != null) ...<Widget>[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.liquidGold.withValues(alpha: 0.5),
                              width: 0.6,
                            ),
                          ),
                          child: Text(
                            widget.rankBadge ?? '${widget.points} Puan',
                            style: const TextStyle(
                              color: AppColors.liquidGold,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

