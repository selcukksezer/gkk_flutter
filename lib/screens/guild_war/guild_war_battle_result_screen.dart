import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/guild_war_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'widgets/faction_crest_painter.dart';
import 'widgets/guild_war_design.dart';
import 'widgets/siege_combat_viewport.dart';

/// Victory & Defeat Celebration VFX painter rendering radiant god-rays,
/// concentric expanding shockwaves, and drifting celebratory embers.
class VictoryCelebrationVfxPainter extends CustomPainter {
  VictoryCelebrationVfxPainter({
    required this.progress,
    required this.isVictory,
  });

  final double progress; // 0.0 to 1.0 (looping)
  final bool isVictory;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height * 0.28;

    final Color primaryGlow =
        isVictory ? AppColors.liquidGold : const Color(0xFFFF1744);
    final Color secondaryGlow =
        isVictory ? const Color(0xFF00E5FF) : const Color(0xFF7C4DFF);

    // 1. Concentric Expanding Shockwave Rings
    for (int i = 0; i < 3; i++) {
      final double ringPhase = (progress + (i * 0.33)) % 1.0;
      final Paint wavePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.8 - (ringPhase * 2.0)).clamp(0.5, 3.0)
        ..color = (i % 2 == 0 ? primaryGlow : secondaryGlow)
            .withValues(alpha: (1.0 - ringPhase).clamp(0.0, 0.65));
      canvas.drawCircle(Offset(cx, cy), 35 + ringPhase * 160, wavePaint);
    }

    // 2. Rotating Radiant God-Rays
    final int rayCount = isVictory ? 16 : 10;
    final double rayAngleOffset = progress * math.pi * 0.5;
    final double rayLength = isVictory ? 220.0 : 160.0;

    final Paint rayPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: <Color>[
          primaryGlow.withValues(alpha: isVictory ? 0.35 : 0.25),
          secondaryGlow.withValues(alpha: isVictory ? 0.15 : 0.10),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: rayLength));

    for (int i = 0; i < rayCount; i++) {
      final double angle = rayAngleOffset + (i * 2 * math.pi / rayCount);
      final double halfWidth = math.pi / (rayCount * 3.5);

      final Path rayPath = Path()
        ..moveTo(cx, cy)
        ..lineTo(
          cx + math.cos(angle - halfWidth) * rayLength,
          cy + math.sin(angle - halfWidth) * rayLength,
        )
        ..lineTo(
          cx + math.cos(angle + halfWidth) * rayLength,
          cy + math.sin(angle + halfWidth) * rayLength,
        )
        ..close();

      canvas.drawPath(rayPath, rayPaint);
    }

    // 3. Floating Celebration Sparks & Embers
    final math.Random rnd = math.Random(42);
    final int sparkCount = isVictory ? 24 : 16;
    for (int i = 0; i < sparkCount; i++) {
      final double baseAngle = rnd.nextDouble() * 2 * math.pi;
      final double speed = 0.5 + rnd.nextDouble() * 1.5;
      final double dist = 30 + ((progress * speed * 120 + i * 18) % 150);
      final double x = cx + math.cos(baseAngle + progress * 0.5) * dist;
      final double y =
          cy + math.sin(baseAngle + progress * 0.5) * dist - (progress * 25);
      final double sparkSize = 1.2 + (rnd.nextDouble() * 2.4);
      final double alpha = (math.sin((dist / 150) * math.pi)).clamp(0.0, 0.9);

      final Paint sparkPaint = Paint()
        ..color = (i % 2 == 0 ? primaryGlow : secondaryGlow)
            .withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), sparkSize, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant VictoryCelebrationVfxPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isVictory != isVictory;
  }
}

/// Golden Laurel Wreath Painter rendering celebratory Imperial Roman / Dark Fantasy laurel leaves.
class GoldenLaurelWreathPainter extends CustomPainter {
  const GoldenLaurelWreathPainter({
    this.animationProgress = 1.0,
    this.isVictory = true,
  });

  final double animationProgress;
  final bool isVictory;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = math.min(cx, cy) * 0.92;

    final Color leafGold =
        isVictory ? AppColors.liquidGold : const Color(0xFF8E9CAE);
    final Color leafHighlight =
        isVictory ? AppColors.goldLight : Colors.white70;
    final Color leafDark =
        isVictory ? const Color(0xFFB8860B) : const Color(0xFF4A5568);

    final Paint branchPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = leafGold;

    // Draw Left and Right curved stems
    final Path leftStem = Path();
    leftStem.moveTo(cx - 8, cy + r * 0.75);
    leftStem.cubicTo(
      cx - r * 0.95,
      cy + r * 0.35,
      cx - r * 0.90,
      cy - r * 0.55,
      cx - 16,
      cy - r * 0.85,
    );
    canvas.drawPath(leftStem, branchPaint);

    final Path rightStem = Path();
    rightStem.moveTo(cx + 8, cy + r * 0.75);
    rightStem.cubicTo(
      cx + r * 0.95,
      cy + r * 0.35,
      cx + r * 0.90,
      cy - r * 0.55,
      cx + 16,
      cy - r * 0.85,
    );
    canvas.drawPath(rightStem, branchPaint);

    // Draw Laurel Leaf pairs along both stems
    const int leafPairs = 7;
    for (int i = 0; i < leafPairs; i++) {
      final double t = (i + 1) / (leafPairs + 1);
      final double leafSize =
          (11.0 + math.sin(t * math.pi) * 6.0) * animationProgress;

      // Sample along left curve
      final double leftAngle = -math.pi * 0.55 + (t * math.pi * 0.95);
      final double lx = cx - r * 0.68 * math.sin(t * math.pi) - 10;
      final double ly = cy + r * 0.75 - (t * 1.55 * r);

      _drawSingleLeaf(
        canvas,
        lx,
        ly,
        leftAngle,
        leafSize,
        leafGold,
        leafHighlight,
        leafDark,
      );

      // Sample along right curve
      final double rightAngle = math.pi * 0.55 - (t * math.pi * 0.95);
      final double rx = cx + r * 0.68 * math.sin(t * math.pi) + 10;
      final double ry = cy + r * 0.75 - (t * 1.55 * r);

      _drawSingleLeaf(
        canvas,
        rx,
        ry,
        rightAngle,
        leafSize,
        leafGold,
        leafHighlight,
        leafDark,
      );
    }

    // Imperial seal medallion at bottom ribbon center
    final Paint medallionPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[leafHighlight, leafGold, leafDark],
      ).createShader(
        Rect.fromCircle(center: Offset(cx, cy + r * 0.78), radius: 10),
      );
    canvas.drawCircle(Offset(cx, cy + r * 0.78), 8, medallionPaint);

    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = leafHighlight;
    canvas.drawCircle(Offset(cx, cy + r * 0.78), 8, borderPaint);

    // Central star or diamond
    final Path star = Path()
      ..moveTo(cx, cy + r * 0.78 - 4)
      ..lineTo(cx + 3, cy + r * 0.78)
      ..lineTo(cx, cy + r * 0.78 + 4)
      ..lineTo(cx - 3, cy + r * 0.78)
      ..close();
    canvas.drawPath(star, Paint()..color = Colors.white);
  }

  void _drawSingleLeaf(
    Canvas canvas,
    double x,
    double y,
    double angle,
    double size,
    Color base,
    Color highlight,
    Color dark,
  ) {
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(angle);

    final Path leaf = Path();
    leaf.moveTo(0, 0);
    leaf.cubicTo(size * 0.4, -size * 0.5, size * 0.8, -size * 0.3, size, 0);
    leaf.cubicTo(size * 0.8, size * 0.3, size * 0.4, size * 0.5, 0, 0);

    final Paint leafFill = Paint()
      ..shader = LinearGradient(
        colors: <Color>[highlight, base, dark],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, -size * 0.5, size, size));

    canvas.drawPath(leaf, leafFill);

    final Paint vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = dark.withValues(alpha: 0.8);
    canvas.drawLine(const Offset(0, 0), Offset(size * 0.85, 0), vein);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GoldenLaurelWreathPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.isVictory != isVictory;
  }
}

/// Dark fantasy Guild War Battle Result Screen.
///
/// Features territory conquest banners, animated guild honor counter rollups,
/// MVP player showcase, defeat/victory fanfare VFX, and interactive simulation replay.
class BattleResultScreen extends StatefulWidget {
  const BattleResultScreen({
    super.key,
    required this.result,
  });

  final GuildWarAttackResult result;

  @override
  State<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends State<BattleResultScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _vfxLoopController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _laurelAnim;
  bool _showReplay = true;

  @override
  void initState() {
    super.initState();
    // Tactile heavy impact feedback upon seeing siege outcome
    HapticFeedback.heavyImpact();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _vfxLoopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _laurelAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _vfxLoopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool success = widget.result.success;
    final Color accent =
        success ? AppColors.liquidGold : const Color(0xFFFF1744);
    final Color accentSubtle =
        success ? const Color(0xFF00E5FF) : const Color(0xFF7C4DFF);

    return Scaffold(
      backgroundColor: WarPalette.void_,
      body: Stack(
        children: <Widget>[
          // 1. Dark Fantasy Ambient Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 1.2,
                  colors: <Color>[
                    accent.withValues(alpha: success ? 0.18 : 0.12),
                    WarPalette.navy.withValues(alpha: 0.85),
                    WarPalette.void_,
                  ],
                ),
              ),
            ),
          ),

          // 2. Celebratory Fanfare VFX Layer
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _vfxLoopController,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: VictoryCelebrationVfxPainter(
                    progress: _vfxLoopController.value,
                    isVictory: success,
                  ),
                );
              },
            ),
          ),

          // 3. Foreground Screen Content
          SafeArea(
            child: Column(
              children: <Widget>[
                // Top Custom Header Navigation
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: <Widget>[
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.pop();
                        },
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141926),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(
                              color: Colors.white24,
                              width: 0.8,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.arrow_back_ios_new_rounded,
                                size: 14,
                                color: AppColors.liquidGold,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Geri',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'LONCA KUŞATMA RAPORU',
                        style: TextStyle(
                          fontFamily: 'Cinzel',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 50),
                    ],
                  ),
                ),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base,
                    ),
                    child: Column(
                      children: <Widget>[
                        const SizedBox(height: AppSpacing.sm),

                        // A. Territory Conquest Banner & Faction Crest Showcase
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (BuildContext context, Widget? child) {
                            return Transform.scale(
                              scale: _scaleAnim.value,
                              child: Opacity(
                                opacity: _fadeAnim.value,
                                child: child,
                              ),
                            );
                          },
                          child: _buildTerritoryConquestBanner(
                            success: success,
                            accent: accent,
                            accentSubtle: accentSubtle,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.base),

                        // B. Guild Honor Gain Rollup Card
                        _buildHonorRollupCard(
                          success: success,
                          accent: accent,
                        ),

                        const SizedBox(height: AppSpacing.base),

                        // C. Siege MVP Player Showcase
                        _buildMvpShowcaseCard(
                          success: success,
                          accent: accent,
                        ),

                        const SizedBox(height: AppSpacing.base),

                        // D. Interactive Siege Combat Replay Viewport
                        _buildSiegeCombatSection(success: success),

                        const SizedBox(height: AppSpacing.base),

                        // E. Battle Stats Breakdown Card
                        _buildBattleStatsCard(
                          accent: accent,
                          accentSubtle: accentSubtle,
                        ),

                        const SizedBox(height: AppSpacing.lg),

                        // F. Primary Action Button
                        _buildBottomAction(
                          context: context,
                          accent: accent,
                        ),

                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Territory Conquest Banner with Golden Laurel Frame & Faction Crest.
  Widget _buildTerritoryConquestBanner({
    required bool success,
    required Color accent,
    required Color accentSubtle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Golden Laurel Wreath framing the single Faction Crest
        SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Golden Laurel Wreath Custom Paint
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, Widget? child) {
                    return CustomPaint(
                      painter: GoldenLaurelWreathPainter(
                        animationProgress: _laurelAnim.value,
                        isVictory: success,
                      ),
                    );
                  },
                ),
              ),

              // Single Faction Crest Widget (Elyos / Asmodian)
              FactionCrestWidget(
                faction: success ? FactionType.elyos : FactionType.asmodian,
                size: 80,
                showGlow: true,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Proclamation Headline
        Text(
          success ? 'BÖLGE ELE GEÇİRİLDİ!' : 'SALDIRI PÜSKÜRTÜLDÜ!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Cinzel',
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: accent,
            shadows: <Shadow>[
              Shadow(
                color: accent.withValues(alpha: 0.65),
                blurRadius: 16,
              ),
            ],
          ),
        ),

        // Territory Name Plaque
        if (widget.result.territoryName != null) ...<Widget>[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(
                color: accent.withValues(alpha: 0.5),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              widget.result.territoryName!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cinzel',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            ),
          ),
        ],

        // Battle Message Subtitle
        if (widget.result.message.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.result.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.75),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Guild Honor Gain Animated Rollup Card.
  Widget _buildHonorRollupCard({
    required bool success,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: const Color(0xFF131724),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: accent.withValues(alpha: 0.4),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.military_tech_rounded,
                size: 20,
                color: AppColors.liquidGold,
              ),
              const SizedBox(width: 8),
              const Text(
                'LONCA ŞEREFİ VE KAZANIMLARI',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.liquidGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                  border: Border.all(
                    color: AppColors.liquidGold.withValues(alpha: 0.4),
                  ),
                ),
                child: const Text(
                  'KADEME IV',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.liquidGold,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Central Counter Rollup Plaque displaying +pointsGained
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    accent.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.4),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                border: Border.all(
                  color: accent.withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.star_rounded,
                    color: accent,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '+${widget.result.pointsGained}',
                    style: TextStyle(
                      fontFamily: 'Cinzel',
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: accent,
                      letterSpacing: 1.2,
                      shadows: <Shadow>[
                        Shadow(
                          color: accent.withValues(alpha: 0.7),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Şeref Puanı',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Honor Progression Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: success ? 0.85 : 0.40,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'Lonca Prestiji: %${success ? 85 : 40}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
              Text(
                success ? 'Sonraki Seviye: 2500 SP' : 'Yenilenme Bekleniyor',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// MVP Player Showcase Card.
  Widget _buildMvpShowcaseCard({
    required bool success,
    required Color accent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: const Color(0xFF111522),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.35),
          width: 0.9,
        ),
      ),
      child: Row(
        children: <Widget>[
          // MVP Golden Laurel Avatar Frame
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  AppColors.liquidGold.withValues(alpha: 0.3),
                  const Color(0xFF0C101A),
                ],
              ),
              border: Border.all(
                color: AppColors.liquidGold,
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.shield_rounded,
                color: AppColors.liquidGold,
                size: 26,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // MVP Player Accolades
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Row(
                  children: <Widget>[
                    Text(
                      'KUŞATMA KAHRAMANI (MVP)',
                      style: TextStyle(
                        fontFamily: 'Cinzel',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.liquidGold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(
                      Icons.workspace_premium_rounded,
                      size: 14,
                      color: AppColors.liquidGold,
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                const Text(
                  'Lejyon Kuşatma Komutanı',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  success
                      ? 'Derece: S+ Efsanevi Fatih · Katkı: %42'
                      : 'Derece: A Direniş Muhafızı · Katkı: %28',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Interactive Siege Combat Replay Viewport Section.
  Widget _buildSiegeCombatSection({required bool success}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D111C),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.videocam_rounded,
                  size: 18,
                  color: AppColors.liquidGold,
                ),
                const SizedBox(width: 8),
                const Text(
                  'KUŞATMA ÇARPIŞMA TEKRARI',
                  style: TextStyle(
                    fontFamily: 'Cinzel',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _showReplay = !_showReplay);
                  },
                  icon: Icon(
                    _showReplay
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppColors.liquidGold,
                  ),
                  label: Text(
                    _showReplay ? 'Gizle' : 'Göster',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.liquidGold,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_showReplay) ...<Widget>[
            const Divider(color: Colors.white10, height: 1),
            SiegeCombatViewport(
              territoryName: widget.result.territoryName ?? 'Bölge Kuşatması',
              attackPower: widget.result.attackPower,
              defensePower: widget.result.defensePower,
              pointsGained: widget.result.pointsGained,
              isVictory: success,
              attackerGuildName: 'Senin Loncan',
              defenderGuildName:
                  widget.result.defenderGuildName ?? 'Savunan Lonca',
              autoPlay: true,
              height: 240,
            ),
          ],
        ],
      ),
    );
  }

  /// Battle Stats Breakdown Card.
  Widget _buildBattleStatsCard({
    required Color accent,
    required Color accentSubtle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.base),
      decoration: BoxDecoration(
        color: const Color(0xFF131724),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Row(
            children: <Widget>[
              Icon(
                Icons.analytics_rounded,
                size: 18,
                color: Colors.white70,
              ),
              SizedBox(width: 8),
              Text(
                'KUŞATMA PERFORMANSI',
                style: TextStyle(
                  fontFamily: 'Cinzel',
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Saldırı Gücü
          _StatRow(
            label: 'Saldırı Gücü',
            value: '${widget.result.attackPower}',
            color: AppColors.coralFlare,
            icon: Icons.sports_martial_arts_rounded,
          ),
          const Divider(color: Colors.white10, height: 1),

          // Savunma Gücü
          _StatRow(
            label: 'Savunma Gücü',
            value: '${widget.result.defensePower}',
            color: accentSubtle,
            icon: Icons.security_rounded,
          ),

          // Can Kaybı (if > 0)
          if (widget.result.healthLost > 0) ...<Widget>[
            const Divider(color: Colors.white10, height: 1),
            _StatRow(
              label: 'Can Kaybı',
              value: '-${widget.result.healthLost} HP',
              color: const Color(0xFFFF5252),
              icon: Icons.favorite_border_rounded,
            ),
          ],

          // Harcanan Lonca Altını (if > 0)
          if (widget.result.goldSpent > 0) ...<Widget>[
            const Divider(color: Colors.white10, height: 1),
            _StatRow(
              label: 'Harcanan Altın',
              value: '${widget.result.goldSpent} 🪙',
              color: const Color(0xFFFFD54F),
              icon: Icons.monetization_on_outlined,
            ),
          ],
        ],
      ),
    );
  }

  /// Primary Bottom Action Button.
  Widget _buildBottomAction({
    required BuildContext context,
    required Color accent,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.heavyImpact();
          context.pop();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.black,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
        child: const Text(
          'HARİTAYA DÖN',
          style: TextStyle(
            fontFamily: 'Cinzel',
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

/// Detailed Stat Row Widget with label, value, color, and icon.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cinzel',
            ),
          ),
        ],
      ),
    );
  }
}
