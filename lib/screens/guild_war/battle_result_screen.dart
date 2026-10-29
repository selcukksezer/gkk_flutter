import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/guild_war_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../l10n/l10n.dart';
import 'widgets/faction_crest_painter.dart';
import 'widgets/siege_combat_viewport.dart';

/// Victory & Defeat Celebration VFX painter rendering radiant god-rays, expanding shockwaves, and sparkling embers.
class VictoryCelebrationVfxPainter extends CustomPainter {
  VictoryCelebrationVfxPainter({
    required this.progress,
    required this.isVictory,
  });

  final double progress; // 0.0 to 1.0
  final bool isVictory;

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height * 0.38;

    final Color primaryGlow = isVictory ? const Color(0xFFFFD54F) : const Color(0xFFFF1744);
    final Color secondaryGlow = isVictory ? const Color(0xFF00E5FF) : const Color(0xFF7C4DFF);

    // 1. Expanding Shockwave Rings
    final Paint wavePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * (1.0 - progress)
      ..color = primaryGlow.withValues(alpha: (1.0 - progress).clamp(0.0, 0.7));

    canvas.drawCircle(Offset(cx, cy), 40 + progress * 140, wavePaint);

    if (progress > 0.2) {
      final double p2 = (progress - 0.2) / 0.8;
      final Paint wavePaint2 = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * (1.0 - p2)
        ..color = secondaryGlow.withValues(alpha: (1.0 - p2).clamp(0.0, 0.5));
      canvas.drawCircle(Offset(cx, cy), 30 + p2 * 110, wavePaint2);
    }

    // 2. Rotating Radiant God-Rays
    final int rayCount = isVictory ? 12 : 8;
    final Paint rayPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: <Color>[
          primaryGlow.withValues(alpha: 0.35 * (1.0 - progress * 0.5)),
          secondaryGlow.withValues(alpha: 0.15 * (1.0 - progress * 0.5)),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 180));

    final double rayAngleOffset = progress * math.pi * 0.25;
    for (int i = 0; i < rayCount; i++) {
      final double angle = (i * 2 * math.pi / rayCount) + rayAngleOffset;
      final Path rayPath = Path();
      rayPath.moveTo(cx, cy);
      rayPath.lineTo(
        cx + math.cos(angle - 0.08) * 170,
        cy + math.sin(angle - 0.08) * 170,
      );
      rayPath.lineTo(
        cx + math.cos(angle + 0.08) * 170,
        cy + math.sin(angle + 0.08) * 170,
      );
      rayPath.close();
      canvas.drawPath(rayPath, rayPaint);
    }

    // 3. Floating Celebration Embers / Sparkles
    final math.Random rng = math.Random(42);
    final Paint sparkPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < 28; i++) {
      final double speed = 0.5 + rng.nextDouble();
      final double sparkProgress = (progress * speed + rng.nextDouble()) % 1.0;
      final double sparkAngle = rng.nextDouble() * 2 * math.pi;
      final double dist = 30 + sparkProgress * 150;

      final double sx = cx + math.cos(sparkAngle) * dist;
      final double sy = cy + math.sin(sparkAngle) * dist;

      final double alpha = (math.sin(sparkProgress * math.pi)).clamp(0.0, 1.0);
      sparkPaint.color = (i % 2 == 0 ? primaryGlow : secondaryGlow).withValues(alpha: alpha);
      final double sparkRadius = 1.5 + rng.nextDouble() * 2.5;

      canvas.drawCircle(Offset(sx, sy), sparkRadius, sparkPaint);
    }
  }

  @override
  bool shouldRepaint(covariant VictoryCelebrationVfxPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.isVictory != isVictory;
  }
}

class BattleResultScreen extends StatefulWidget {
  const BattleResultScreen({super.key, required this.result});

  final GuildWarAttackResult result;

  @override
  State<BattleResultScreen> createState() => _BattleResultScreenState();
}

class _BattleResultScreenState extends State<BattleResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _vfxLoopController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _showReplay = true;

  @override
  void initState() {
    super.initState();
    // Tactile heavy impact feedback on duel/battle result presentation
    HapticFeedback.heavyImpact();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _vfxLoopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _scaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.2, 0.8)),
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
    final Color accent = success ? AppColors.liquidGold : AppColors.mysticRuby;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C14),
      body: Stack(
        children: <Widget>[
          // Background Celebration VFX
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

          // Foreground Scrollable Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              child: Column(
                children: <Widget>[
                  // Top Navigation Bar
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.sm,
                        AppSpacing.sm,
                        AppSpacing.sm,
                        0,
                      ),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.pop();
                        },
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141926),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(color: Colors.white24, width: 0.8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.liquidGold),
                              SizedBox(width: 6),
                              Text(
                                'Geri',
                                style: TextStyle(
                                  color: AppColors.liquidGold,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Animated Victory / Defeat Badge & Crest
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
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Crest Widget
                        FactionCrestWidget(
                          faction: success ? FactionType.elyos : FactionType.asmodian,
                          size: 88,
                          showGlow: true,
                        ),
                        const SizedBox(height: 14),

                        // Result Title with Glow
                        Text(
                          success ? 'BÖLGE ELE GEÇÝRÝLDÝ!' : 'SALDIRI PÜSKÜRTÜLDÜ!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Cinzel',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: accent,
                            shadows: <Shadow>[
                              Shadow(
                                color: accent.withValues(alpha: 0.8),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                        ),
                        if (widget.result.territoryName != null) ...<Widget>[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              widget.result.territoryName!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.base),

                  // Interactive Siege Battle Replay Viewport (All 9 Combat VFX & Juice Modules)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text(
                              '?? KUÞATMA ÇARPIÞMA TEKRARI & VFX',
                              style: TextStyle(
                                color: AppColors.liquidGold,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                setState(() => _showReplay = !_showReplay);
                              },
                              icon: Icon(
                                _showReplay ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 14,
                                color: Colors.white70,
                              ),
                              label: Text(
                                _showReplay ? 'Gizle' : 'Göster',
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        if (_showReplay) ...<Widget>[
                          const SizedBox(height: 4),
                          SiegeCombatViewport(
                            territoryName: widget.result.territoryName ?? 'Kale Kuþatmasý',
                            attackPower: widget.result.attackPower,
                            defensePower: widget.result.defensePower,
                            pointsGained: widget.result.pointsGained,
                            isVictory: success,
                            defenderGuildName: widget.result.defenderGuildName ?? 'Savunan Lonca',
                            autoPlay: true,
                            height: 310,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.base),

                  // Battle Stats Card (100% preservation of scoring and commander HP)
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.base),
                      decoration: BoxDecoration(
                        color: const Color(0xFF131724),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _StatRow(
                            label: context.l10n.sald_r_g_c,
                            value: '',
                            color: AppColors.coralFlare,
                          ),
                          const Divider(color: Colors.white10),
                          _StatRow(
                            label: context.l10n.savunma_g_c,
                            value: '',
                            color: const Color(0xFF00E5FF),
                          ),
                          const Divider(color: Colors.white10),
                          _StatRow(
                            label: context.l10n.kazan_lan_puan,
                            value: '+',
                            color: AppColors.liquidGold,
                          ),
                          if (widget.result.healthLost > 0) ...<Widget>[
                            const Divider(color: Colors.white10),
                            _StatRow(
                              label: 'Kaybedilen Komutan Caný',
                              value: '- HP',
                              color: const Color(0xFFFF5252),
                            ),
                          ],
                          if (widget.result.goldSpent > 0) ...<Widget>[
                            const Divider(color: Colors.white10),
                            _StatRow(
                              label: 'Harcanan Kasa Altýný',
                              value: ' ??',
                              color: const Color(0xFFFFD54F),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Thumb-friendly Bottom Action Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          context.pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 8,
                          shadowColor: accent.withValues(alpha: 0.5),
                        ),
                        child: Text(
                          context.l10n.devam,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
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
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
