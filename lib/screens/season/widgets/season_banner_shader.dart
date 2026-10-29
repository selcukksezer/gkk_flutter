import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/economy_constants.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../providers/battle_pass_provider.dart';
import '../../../theme/app_colors.dart';

/// 2027 Aion 2 Mobile Season Banner with Cosmic Shimmer & Daeva Wing Particles.
/// Responsive for 390x844 mobile viewport with strict SafeArea enforcement.
class SeasonBannerShader extends StatefulWidget {
  const SeasonBannerShader({
    super.key,
    required this.state,
    required this.daysLeft,
    required this.onBuyVip,
    required this.isVipBuying,
    this.enableShaderAnimation = true,
    this.onTap,
    this.margin,
  });

  final BattlePassState state;
  final int daysLeft;
  final VoidCallback onBuyVip;
  final bool isVipBuying;
  final bool enableShaderAnimation;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  State<SeasonBannerShader> createState() => _SeasonBannerShaderState();
}

class _SeasonBannerShaderState extends State<SeasonBannerShader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.enableShaderAnimation) {
      _animCtrl.repeat();
    }
  }

  @override
  void didUpdateWidget(SeasonBannerShader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableShaderAnimation != widget.enableShaderAnimation) {
      if (widget.enableShaderAnimation) {
        if (!_animCtrl.isAnimating) _animCtrl.repeat();
      } else {
        _animCtrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.state.status;
    final season = widget.state.activeSeason;
    final int seasonNumber = season?.seasonNumber ?? 1;
    final int currentBpp = status?.currentBpp ?? 0;
    final int level = status?.currentLevel ?? 0;
    final int xpInCurrentLevel = currentBpp % 1000;
    final double progress = (xpInCurrentLevel / 1000.0).clamp(0.0, 1.0);
    final bool hasVip = status?.hasVip ?? false;
    final bool disableAnimations = !widget.enableShaderAnimation ||
        (MediaQuery.maybeOf(context)?.disableAnimations ?? false);

    return RepaintBoundary(
      child: TutorialAnchorScope(
        id: TutorialAnchorId.seasonHeader,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap ?? () {},
          child: Container(
            margin: widget.margin,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: hasVip
                    ? AppColors.liquidGold.withValues(alpha: 0.75)
                    : AppColors.accentCyan.withValues(alpha: 0.4),
                width: hasVip ? 1.5 : 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: hasVip
                      ? AppColors.liquidGold.withValues(alpha: 0.25)
                      : AppColors.accentCyan.withValues(alpha: 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
                const BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Stack(
                children: <Widget>[
                  // Animated Cosmic Daeva Particle & Shader Sweep Background
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: _CosmicDaevaBannerPainter(
                          animation: _animCtrl,
                          hasVip: hasVip,
                          disableAnimations: disableAnimations,
                        ),
                      ),
                    ),
                  ),

                  // Frosted Glass Highlight Gradient
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Colors.white.withValues(alpha: 0.08),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.45),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Specular Hairline Rim Light (Top Edge)
                  Positioned(
                    top: 0,
                    left: 20,
                    right: 20,
                    height: 1.0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            hasVip
                                ? AppColors.liquidGold.withValues(alpha: 0.5)
                                : AppColors.accentCyan.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                // Foreground Content
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Top Row: Title, Season Subtitle, VIP Badge or Buy Button
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          // Season Crest / Icon
                          _buildSeasonEmblem(hasVip),
                          const SizedBox(width: 8),
                          // Title & Remaining Days
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 4,
                                  runSpacing: 2,
                                  children: <Widget>[
                                    Text(
                                      'SEZON $seasonNumber',
                                      style: GoogleFonts.cinzel(
                                        color: hasVip
                                            ? AppColors.liquidGold
                                            : Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: hasVip
                                            ? AppColors.liquidGold
                                                .withValues(alpha: 0.2)
                                            : AppColors.accentCyan
                                                .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: hasVip
                                              ? AppColors.liquidGold
                                                  .withValues(alpha: 0.5)
                                              : AppColors.accentCyan
                                                  .withValues(alpha: 0.4),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        hasVip ? 'DAEVA' : 'KLASİK',
                                        style: TextStyle(
                                          color: hasVip
                                              ? AppColors.liquidGold
                                              : AppColors.accentCyan,
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: <Widget>[
                                    Icon(
                                      Icons.timer_outlined,
                                      size: 11,
                                      color: Colors.white.withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        widget.daysLeft > 0
                                            ? '${widget.daysLeft} gün kaldı'
                                            : 'Bugün bitiyor',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.7),
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // VIP Badge or Buy VIP Button
                          if (hasVip)
                            _buildDaevaActiveBadge()
                          else
                            _buildVipBuyButton(widget.onBuyVip, widget.isVipBuying),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Level Medallion & BPP Progress Bar
                      TutorialAnchorScope(
                        id: TutorialAnchorId.seasonBppBar,
                        child: Row(
                          children: <Widget>[
                            _buildCosmicLevelRing(level, progress, hasVip),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          'BPP İLERLEMESİ',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Color(0xFFC7D2FE),
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$xpInCurrentLevel / 1000',
                                        style: TextStyle(
                                          color: hasVip
                                              ? AppColors.liquidGold
                                              : AppColors.accentCyan,
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  _buildGlowingProgressBar(progress, hasVip),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Daily Grind & PvP Caps
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _buildCapCard(
                              icon: '🏰',
                              label: 'Zindan BPP',
                              current: status?.dailyGrindBppPool ?? 0,
                              max: 300,
                              accentColor: const Color(0xFF38BDF8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildCapCard(
                              icon: '⚔️',
                              label: 'PvP BPP',
                              current: status?.dailyPvpBppPool ?? 0,
                              max: 200,
                              accentColor: const Color(0xFFF43F5E),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }

  Widget _buildSeasonEmblem(bool hasVip) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: hasVip
              ? <Color>[
                  AppColors.liquidGold.withValues(alpha: 0.45),
                  const Color(0x33B8860B),
                  Colors.transparent,
                ]
              : <Color>[
                  AppColors.accentCyan.withValues(alpha: 0.4),
                  const Color(0x2238BDF8),
                  Colors.transparent,
                ],
        ),
        border: Border.all(
          color: hasVip ? AppColors.liquidGold : AppColors.accentCyan,
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (hasVip ? AppColors.liquidGold : AppColors.accentCyan)
                .withValues(alpha: 0.25),
            blurRadius: 8,
          ),
        ],
      ),
      child: Center(
        child: Icon(
          hasVip ? Icons.auto_awesome_rounded : Icons.shield_rounded,
          color: hasVip ? AppColors.liquidGold : AppColors.accentCyan,
          size: 19,
        ),
      ),
    );
  }

  Widget _buildDaevaActiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        gradient: AppColors.liquidGoldGradient,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: const Color(0xFFFFF7C2),
          width: 0.7,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.liquidGold.withValues(alpha: 0.45),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.workspace_premium_rounded,
              size: 13, color: AppColors.carbonVoid),
          SizedBox(width: 3.5),
          Text(
            'DAEVA VIP',
            style: TextStyle(
              color: AppColors.carbonVoid,
              fontWeight: FontWeight.w900,
              fontSize: 9.5,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVipBuyButton(VoidCallback onBuy, bool isBuying) {
    final int cost = EconomyConstants.battlePassVipGemCost;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isBuying ? null : onBuy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: isBuying ? null : AppColors.liquidGoldGradient,
          color: isBuying ? const Color(0x44FFFFFF) : null,
          borderRadius: BorderRadius.circular(9),
          border: isBuying
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.2), width: 0.8)
              : Border.all(color: const Color(0xFFFFF7C2), width: 0.8),
          boxShadow: isBuying
              ? null
              : <BoxShadow>[
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.4),
                    blurRadius: 9,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: isBuying
            ? const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.liquidGold,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Icon(Icons.diamond_rounded,
                      size: 12, color: AppColors.carbonVoid),
                  const SizedBox(width: 3),
                  Text(
                    'VIP · $cost',
                    style: const TextStyle(
                      color: AppColors.carbonVoid,
                      fontWeight: FontWeight.w900,
                      fontSize: 9.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCosmicLevelRing(int level, double progress, bool hasVip) {
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 3.2,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                hasVip ? AppColors.liquidGold : AppColors.accentCyan,
              ),
            ),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: hasVip
                    ? <Color>[
                        const Color(0xFF4A3408),
                        const Color(0xFF1E1508),
                      ]
                    : <Color>[
                        const Color(0xFF0C2738),
                        const Color(0xFF061420),
                      ],
              ),
              border: Border.all(
                color: hasVip
                    ? AppColors.liquidGold.withValues(alpha: 0.75)
                    : AppColors.accentCyan.withValues(alpha: 0.65),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: (hasVip ? AppColors.liquidGold : AppColors.accentCyan)
                      .withValues(alpha: 0.25),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Center(
              child: Text(
                '$level',
                style: GoogleFonts.urbanist(
                  color: hasVip ? AppColors.liquidGold : Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlowingProgressBar(double progress, bool hasVip) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 7,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Stack(
          children: <Widget>[
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: hasVip
                        ? const <Color>[
                            Color(0xFFB8860B),
                            AppColors.liquidGold,
                            Color(0xFFFFF7C2),
                          ]
                        : const <Color>[
                            Color(0xFF0284C7),
                            AppColors.accentCyan,
                            Color(0xFFBAE6FD),
                          ],
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: (hasVip
                              ? AppColors.liquidGold
                              : AppColors.accentCyan)
                          .withValues(alpha: 0.65),
                      blurRadius: 6,
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

  Widget _buildCapCard({
    required String icon,
    required String label,
    required int current,
    required int max,
    required Color accentColor,
  }) {
    final bool isFull = current >= max;
    final Color barColor = isFull ? AppColors.danger : accentColor;
    final double pct = max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: isFull
              ? AppColors.danger.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(icon, style: const TextStyle(fontSize: 10)),
              const SizedBox(width: 3.5),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: isFull
                    ? const EdgeInsets.symmetric(horizontal: 4, vertical: 1)
                    : EdgeInsets.zero,
                decoration: isFull
                    ? BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.4),
                          width: 0.6,
                        ),
                      )
                    : null,
                child: Text(
                  isFull ? 'DOLDU' : '$current/$max',
                  style: TextStyle(
                    color: barColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 3.5,
              color: Colors.white.withValues(alpha: 0.06),
              child: FractionallySizedBox(
                widthFactor: pct,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        barColor.withValues(alpha: 0.6),
                        barColor,
                      ],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: barColor.withValues(alpha: 0.4),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter simulating cosmic nebulas, animated specular sweeps,
/// floating astral stardust, cross flares, and Daeva wing silhouettes.
/// Optimized with super(repaint) to ensure zero-jank frame renders without widget rebuilds.
class _CosmicDaevaBannerPainter extends CustomPainter {
  _CosmicDaevaBannerPainter({
    required this.animation,
    required this.hasVip,
    this.disableAnimations = false,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final bool hasVip;
  final bool disableAnimations;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // 1. Deep cosmic gradient base
    final Paint basePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: hasVip
            ? const <Color>[
                Color(0xFF261906),
                Color(0xFF140F0A),
                Color(0xFF1B1425),
              ]
            : const <Color>[
                Color(0xFF0B1728),
                Color(0xFF080C14),
                Color(0xFF131024),
              ],
      ).createShader(rect);
    canvas.drawRect(rect, basePaint);

    final double animValue = disableAnimations ? 0.0 : animation.value;

    // 2. Animated Cosmic Nebula Blends
    final double nebulaShift = animValue * 2 * math.pi;
    final Offset nebulaCenter1 = Offset(
      size.width * (0.25 + 0.1 * math.sin(nebulaShift)),
      size.height * (0.4 + 0.15 * math.cos(nebulaShift)),
    );
    final Paint nebulaPaint1 = Paint()
      ..shader = RadialGradient(
        colors: hasVip
            ? <Color>[
                AppColors.liquidGold.withValues(alpha: 0.18),
                Colors.transparent,
              ]
            : <Color>[
                AppColors.accentCyan.withValues(alpha: 0.16),
                Colors.transparent,
              ],
      ).createShader(
          Rect.fromCircle(center: nebulaCenter1, radius: size.width * 0.48));
    canvas.drawCircle(nebulaCenter1, size.width * 0.48, nebulaPaint1);

    final Offset nebulaCenter2 = Offset(
      size.width * (0.8 - 0.1 * math.cos(nebulaShift * 0.9)),
      size.height * (0.6 - 0.15 * math.sin(nebulaShift * 0.9)),
    );
    final Paint nebulaPaint2 = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          const Color(0xFF8B5CF6).withValues(alpha: 0.14),
          Colors.transparent,
        ],
      ).createShader(
          Rect.fromCircle(center: nebulaCenter2, radius: size.width * 0.42));
    canvas.drawCircle(nebulaCenter2, size.width * 0.42, nebulaPaint2);

    // 3. Constellation Sacred Geometry
    _drawConstellations(canvas, size, hasVip);

    // 4. Ethereal Daeva Wing Silhouettes in Background
    _drawDaevaWingSilhouettes(canvas, size, animValue, hasVip);

    // 5. Floating Cosmic Stardust & Celestial Diamond Flares
    _drawCosmicParticles(canvas, size, animValue, hasVip);

    // 6. Dynamic Prismatic Light Sweep (Animated Shader simulation)
    _drawShaderSweep(canvas, size, animValue, hasVip);
  }

  void _drawConstellations(Canvas canvas, Size size, bool hasVip) {
    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = (hasVip ? AppColors.liquidGold : AppColors.accentCyan)
          .withValues(alpha: 0.08);

    final Path constellPath = Path()
      ..moveTo(size.width * 0.18, size.height * 0.28)
      ..lineTo(size.width * 0.32, size.height * 0.15)
      ..lineTo(size.width * 0.46, size.height * 0.22)
      ..lineTo(size.width * 0.65, size.height * 0.18)
      ..lineTo(size.width * 0.76, size.height * 0.34)
      ..lineTo(size.width * 0.88, size.height * 0.68);

    canvas.drawPath(constellPath, linePaint);
  }

  void _drawDaevaWingSilhouettes(
      Canvas canvas, Size size, double progress, bool hasVip) {
    final double pulse = disableAnimations
        ? 1.0
        : (0.96 + 0.04 * math.sin(progress * 2 * math.pi));

    final Paint primaryWingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        colors: hasVip
            ? <Color>[
                AppColors.liquidGold.withValues(alpha: 0.24),
                AppColors.liquidGold.withValues(alpha: 0.02),
              ]
            : <Color>[
                AppColors.accentCyan.withValues(alpha: 0.24),
                AppColors.accentCyan.withValues(alpha: 0.02),
              ],
      ).createShader(Offset.zero & size);

    final Paint secondaryWingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..shader = LinearGradient(
        colors: hasVip
            ? <Color>[
                const Color(0xFFFFF7C2).withValues(alpha: 0.16),
                Colors.transparent,
              ]
            : <Color>[
                const Color(0xFFBAE6FD).withValues(alpha: 0.16),
                Colors.transparent,
              ],
      ).createShader(Offset.zero & size);

    // Right Wing arcs
    final double rx = size.width * 0.92;
    final double ry = size.height * 0.45;
    final Path rightWing = Path()
      ..moveTo(rx - 45 * pulse, ry + 32)
      ..quadraticBezierTo(
        rx - 12 * pulse,
        ry - 42 * pulse,
        rx + 22 * pulse,
        ry - 22 * pulse,
      )
      ..quadraticBezierTo(
        rx + 6,
        ry + 10,
        rx - 45 * pulse,
        ry + 32,
      );
    canvas.drawPath(rightWing, primaryWingPaint);

    final Path rightFeather = Path()
      ..moveTo(rx - 32 * pulse, ry + 22)
      ..quadraticBezierTo(
        rx - 8 * pulse,
        ry - 26 * pulse,
        rx + 12 * pulse,
        ry - 10 * pulse,
      );
    canvas.drawPath(rightFeather, secondaryWingPaint);

    // Left Wing arcs
    final double lx = size.width * 0.08;
    final double ly = size.height * 0.45;
    final Path leftWing = Path()
      ..moveTo(lx + 45 * pulse, ly + 32)
      ..quadraticBezierTo(
        lx + 12 * pulse,
        ly - 42 * pulse,
        lx - 22 * pulse,
        ly - 22 * pulse,
      )
      ..quadraticBezierTo(
        lx - 6,
        ly + 10,
        lx + 45 * pulse,
        ly + 32,
      );
    canvas.drawPath(leftWing, primaryWingPaint);

    final Path leftFeather = Path()
      ..moveTo(lx + 32 * pulse, ly + 22)
      ..quadraticBezierTo(
        lx + 8 * pulse,
        ly - 26 * pulse,
        lx - 12 * pulse,
        ly - 10 * pulse,
      );
    canvas.drawPath(leftFeather, secondaryWingPaint);
  }

  void _drawCosmicParticles(
      Canvas canvas, Size size, double progress, bool hasVip) {
    final Paint starPaint = Paint()..style = PaintingStyle.fill;
    final Color primaryColor =
        hasVip ? AppColors.liquidGold : AppColors.accentCyan;

    // 28 astral embers / stardust drifting gently upward
    for (int i = 0; i < 28; i++) {
      final double seed = (i * 37.17) % 1.0;
      final double speed = 0.35 + (i % 5) * 0.12;
      final double yRel = disableAnimations
          ? ((seed * 1.3) % 1.0)
          : ((seed + progress * speed) % 1.0);
      final double xRel = ((seed * 7.91 + i * 0.13) % 1.0);

      final double px = xRel * size.width;
      final double py = (1.0 - yRel) * size.height;
      final double pSize = 1.0 + (i % 3) * 0.75;
      final double opacity = disableAnimations
          ? (0.35 + 0.35 * math.sin(seed * math.pi)).clamp(0.0, 1.0)
          : (0.25 + 0.65 * math.sin((progress * 3 + i) * math.pi))
              .clamp(0.0, 1.0);

      starPaint.color = primaryColor.withValues(alpha: opacity * 0.65);
      canvas.drawCircle(Offset(px, py), pSize, starPaint);

      if (i % 4 == 0) {
        starPaint.color = Colors.white.withValues(alpha: opacity * 0.85);
        canvas.drawCircle(Offset(px, py), pSize * 0.45, starPaint);
      }
    }

    // 4 Sacred Empyrean Cross Flares (Diamond Stars)
    final List<Offset> sacredNodes = <Offset>[
      Offset(size.width * 0.18, size.height * 0.28),
      Offset(size.width * 0.46, size.height * 0.22),
      Offset(size.width * 0.76, size.height * 0.34),
      Offset(size.width * 0.88, size.height * 0.68),
    ];

    for (int j = 0; j < sacredNodes.length; j++) {
      final Offset node = sacredNodes[j];
      final double flarePhase = disableAnimations
          ? 0.7
          : (0.3 +
              0.7 * math.sin((progress * 2.5 + j * 0.7) * math.pi).abs());
      final double flareLen = (3.5 + (j % 2) * 2.0) * flarePhase;

      final Paint flarePaint = Paint()
        ..color = (hasVip
                ? const Color(0xFFFFF3B0)
                : const Color(0xFFBAE6FD))
            .withValues(alpha: (0.45 * flarePhase).clamp(0.0, 1.0))
        ..strokeWidth = 0.9
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(node.dx - flareLen, node.dy),
        Offset(node.dx + flareLen, node.dy),
        flarePaint,
      );
      canvas.drawLine(
        Offset(node.dx, node.dy - flareLen),
        Offset(node.dx, node.dy + flareLen),
        flarePaint,
      );

      canvas.drawCircle(
        node,
        1.1 * flarePhase,
        Paint()
          ..color = Colors.white
              .withValues(alpha: (0.85 * flarePhase).clamp(0.0, 1.0)),
      );
    }
  }

  void _drawShaderSweep(
      Canvas canvas, Size size, double progress, bool hasVip) {
    if (disableAnimations) return;

    // Prismatic diagonal high-specular sheen sweeping across the banner
    final double sweepX = -size.width * 0.35 + (size.width * 1.7) * progress;
    final Rect bannerRect = Offset.zero & size;

    canvas.save();
    canvas.clipRect(bannerRect);
    canvas.translate(sweepX, size.height * 0.5);
    canvas.rotate(math.pi / 6); // 30-degree diagonal sweep

    final double beamWidth = size.width * 0.42;
    final Rect beamRect = Rect.fromCenter(
      center: Offset.zero,
      width: beamWidth,
      height: size.height * 2.5,
    );

    final Color sweepTint =
        hasVip ? AppColors.liquidGold : AppColors.accentCyan;
    final Color sweepCore =
        hasVip ? const Color(0xFFFFF9DE) : const Color(0xFFF0F9FF);

    final Paint sweepPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.transparent,
          sweepTint.withValues(alpha: 0.03),
          sweepCore.withValues(alpha: 0.16),
          sweepTint.withValues(alpha: 0.03),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.32, 0.5, 0.68, 1.0],
      ).createShader(beamRect);

    canvas.drawRect(beamRect, sweepPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CosmicDaevaBannerPainter oldDelegate) {
    return oldDelegate.hasVip != hasVip ||
        oldDelegate.disableAnimations != disableAnimations;
  }
}
