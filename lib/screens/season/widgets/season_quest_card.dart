import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/services/app_haptics.dart';
import '../../../models/battle_pass.dart';
import '../../../theme/app_colors.dart';

/// 2027 Aion 2 Mobile Season Quest Card with V3 AAA Cyber-Fantasy luxury styling.
/// Features glass surface, cyan-to-gold gradient progress bar, pulsing claim CTA
/// button with AppHaptics feedback and celebration confetti burst.
class SeasonQuestCard extends StatefulWidget {
  const SeasonQuestCard({
    super.key,
    required this.quest,
    required this.claiming,
    required this.onClaim,
  });

  final BpPlayerQuest quest;
  final bool claiming;
  final VoidCallback onClaim;

  @override
  State<SeasonQuestCard> createState() => _SeasonQuestCardState();
}

class _SeasonQuestCardState extends State<SeasonQuestCard>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  late final AnimationController _confettiController;
  late final List<_QuestConfettiParticle> _confettiParticles = <_QuestConfettiParticle>[];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _confettiParticles.addAll(_generateParticles());

    if (_isClaimable(widget.quest)) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant SeasonQuestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool oldClaimable = _isClaimable(oldWidget.quest);
    final bool newClaimable = _isClaimable(widget.quest);

    if (newClaimable && !oldClaimable) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else if (!newClaimable && oldClaimable) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  bool _isClaimable(BpPlayerQuest quest) =>
      quest.isCompleted && !quest.rewardClaimed;

  List<_QuestConfettiParticle> _generateParticles() {
    final List<_QuestConfettiParticle> list = <_QuestConfettiParticle>[];
    const List<Color> palette = <Color>[
      AppColors.liquidGold,
      AppColors.goldLight,
      AppColors.accentCyan,
      Color(0xFF00E5FF),
      Color(0xFF4ADE80),
      Color(0xFFC084FC),
      Color(0xFFFFFFFF),
    ];

    for (int i = 0; i < 36; i++) {
      final double angle = -math.pi * 0.85 + _random.nextDouble() * (math.pi * 0.7);
      final double speed = 0.65 + _random.nextDouble() * 0.75;
      final double gravity = 0.65 + _random.nextDouble() * 0.55;
      final double size = 2.4 + _random.nextDouble() * 3.8;
      final Color color = palette[_random.nextInt(palette.length)];
      final double rotationSpeed = (_random.nextDouble() - 0.5) * 7.0;
      final double delay = _random.nextDouble() * 0.18;
      final bool isSparkle = _random.nextBool();

      list.add(
        _QuestConfettiParticle(
          angle: angle,
          speed: speed,
          gravity: gravity,
          size: size,
          color: color,
          rotationSpeed: rotationSpeed,
          delay: delay,
          isSparkle: isSparkle,
        ),
      );
    }
    return list;
  }

  Future<void> _handleClaimTap() async {
    if (widget.claiming) return;
    await AppHaptics.success();
    _confettiParticles.clear();
    _confettiParticles.addAll(_generateParticles());
    _confettiController.forward(from: 0.0);
    widget.onClaim();
  }

  @override
  Widget build(BuildContext context) {
    final BpPlayerQuest quest = widget.quest;
    final BpQuestTemplate? template = quest.template;
    final bool isDaily = template?.questType == 'daily';
    final Color typeColor = isDaily ? AppColors.accentCyan : const Color(0xFFC084FC);
    final int target = template?.targetCount ?? 1;
    final double progress =
        target > 0 ? (quest.currentProgress / target).clamp(0.0, 1.0) : 0.0;
    final bool claimable = _isClaimable(quest);
    final bool claimed = quest.rewardClaimed;

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (BuildContext context, Widget? child) {
            final double pulse = claimable ? _pulseAnimation.value : 0.0;

            final Color borderColor = claimable
                ? Color.lerp(
                    const Color(0xFF4ADE80),
                    AppColors.liquidGold,
                    pulse,
                  )!.withValues(alpha: 0.7 + 0.3 * pulse)
                : claimed
                    ? Colors.white.withValues(alpha: 0.06)
                    : typeColor.withValues(alpha: 0.28);

            final double borderWidth = claimable ? 1.4 : 0.9;

            final List<BoxShadow> shadows = <BoxShadow>[
              if (claimable) ...<BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF4ADE80).withValues(alpha: 0.16 + 0.12 * pulse),
                  blurRadius: 14 + 6 * pulse,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: AppColors.liquidGold.withValues(alpha: 0.08 + 0.08 * pulse),
                  blurRadius: 22,
                ),
              ] else if (!claimed)
                BoxShadow(
                  color: typeColor.withValues(alpha: 0.06),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
            ];

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: borderWidth),
                boxShadow: shadows,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: claimable
                            ? const <Color>[
                                Color(0xF2141F32),
                                Color(0xF20F1626),
                              ]
                            : claimed
                                ? const <Color>[
                                    Color(0xCC0D121D),
                                    Color(0x99101624),
                                  ]
                                : const <Color>[
                                    Color(0xEE131B2D),
                                    Color(0xEE0E1423),
                                  ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildHeader(context, template, isDaily, typeColor, claimable, claimed, pulse),
                        const SizedBox(height: 10),
                        _buildDescription(template, claimed),
                        const SizedBox(height: 12),
                        _buildProgressBar(context, typeColor, progress, target, quest.isCompleted, claimed),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Confetti burst layer positioned over the card
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (BuildContext context, Widget? child) {
                return CustomPaint(
                  painter: _CardConfettiPainter(
                    progress: _confettiController.value,
                    particles: _confettiParticles,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    BpQuestTemplate? template,
    bool isDaily,
    Color typeColor,
    bool claimable,
    bool claimed,
    double pulse,
  ) {
    return Row(
      children: <Widget>[
        // Daily / Weekly holographic pill badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: typeColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: typeColor.withValues(alpha: 0.55),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                isDaily ? Icons.bolt_rounded : Icons.auto_awesome_rounded,
                size: 11,
                color: typeColor,
              ),
              const SizedBox(width: 4),
              Text(
                isDaily ? 'GÜNLÜK GÖREV' : 'HAFTALIK GÖREV',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: typeColor,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        if (template?.targetSystem != null &&
            template!.targetSystem.trim().isNotEmpty) ...<Widget>[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.6,
              ),
            ),
            child: Text(
              template.targetSystem.toUpperCase(),
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: Colors.white.withValues(alpha: 0.55),
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
        const Spacer(),
        // Trailing status / action CTA
        if (claimable)
          _buildClaimButton(template, pulse)
        else if (claimed)
          _buildClaimedBadge()
        else
          _buildRewardPreviewBadge(template),
      ],
    );
  }

  Widget _buildClaimButton(BpQuestTemplate? template, double pulse) {
    return Transform.scale(
      scale: 1.0 + 0.03 * pulse,
      child: GestureDetector(
        onTap: widget.claiming ? null : _handleClaimTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5.5),
          decoration: BoxDecoration(
            gradient: widget.claiming
                ? null
                : const LinearGradient(
                    colors: <Color>[
                      Color(0xFFFFB800),
                      Color(0xFFFDE68A),
                      Color(0xFFFF9E00),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: widget.claiming ? const Color(0x44FFFFFF) : null,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.6 + 0.3 * pulse),
              width: 1.0,
            ),
            boxShadow: widget.claiming
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.45 + 0.25 * pulse),
                      blurRadius: 12 + 6 * pulse,
                      offset: const Offset(0, 2),
                    ),
                    BoxShadow(
                      color: const Color(0xFF4ADE80).withValues(alpha: 0.25 * pulse),
                      blurRadius: 8,
                    ),
                  ],
          ),
          child: widget.claiming
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
                    const Icon(
                      Icons.stars_rounded,
                      size: 13,
                      color: AppColors.carbonVoid,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${template?.bppReward ?? 0} BPP AL',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.carbonVoid,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildClaimedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: const Color(0x1A4ADE80),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: const Color(0x404ADE80),
          width: 0.8,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF4ADE80),
            size: 13,
          ),
          SizedBox(width: 4),
          Text(
            'ALINDI',
            style: TextStyle(
              color: Color(0xFF4ADE80),
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardPreviewBadge(BpQuestTemplate? template) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.liquidGold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.38),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.military_tech_rounded,
            size: 12,
            color: AppColors.liquidGold,
          ),
          const SizedBox(width: 3),
          Text(
            '+${template?.bppReward ?? 0} BPP',
            style: const TextStyle(
              color: AppColors.liquidGold,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription(BpQuestTemplate? template, bool claimed) {
    return Text(
      template?.description ?? '',
      style: TextStyle(
        color: claimed ? const Color(0xFF8A9BBE) : Colors.white,
        fontWeight: claimed ? FontWeight.w500 : FontWeight.w600,
        fontSize: 13.5,
        height: 1.35,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildProgressBar(
    BuildContext context,
    Color typeColor,
    double progress,
    int target,
    bool isCompleted,
    bool claimed,
  ) {
    final int current = widget.quest.currentProgress;

    // Cyber cyan to gold gradient
    final LinearGradient barGradient = isCompleted
        ? const LinearGradient(
            colors: <Color>[
              Color(0xFF00E5FF),
              Color(0xFF06D0D8),
              Color(0xFF4ADE80),
              AppColors.liquidGold,
            ],
          )
        : const LinearGradient(
            colors: <Color>[
              Color(0xFF00E5FF),
              Color(0xFF06D0D8),
              Color(0xFFFFB800),
              Color(0xFFFDE68A),
            ],
          );

    final Color metricColor = isCompleted
        ? const Color(0xFF4ADE80)
        : const Color(0xFF94A3B8);

    return Row(
      children: <Widget>[
        Expanded(
          child: Container(
            height: 7.5,
            decoration: BoxDecoration(
              color: const Color(0xFF090E17),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 0.7,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4.5),
              child: Stack(
                children: <Widget>[
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0.0, end: progress),
                    builder: (BuildContext context, double animatedProgress, Widget? child) {
                      return FractionallySizedBox(
                        widthFactor: animatedProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: barGradient,
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              '$current / $target',
              style: TextStyle(
                color: metricColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 5),
            if (isCompleted)
              Container(
                padding: const EdgeInsets.all(1.5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x334ADE80),
                ),
                child: const Icon(
                  Icons.check,
                  size: 10,
                  color: Color(0xFF4ADE80),
                ),
              )
            else
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentCyan.withValues(alpha: 0.75),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Micro confetti particle for celebratory quest reward claim explosion.
class _QuestConfettiParticle {
  _QuestConfettiParticle({
    required this.angle,
    required this.speed,
    required this.gravity,
    required this.size,
    required this.color,
    required this.rotationSpeed,
    required this.delay,
    required this.isSparkle,
  });

  final double angle;
  final double speed;
  final double gravity;
  final double size;
  final Color color;
  final double rotationSpeed;
  final double delay;
  final bool isSparkle;
}

/// Custom painter rendering celebratory particles bursting from the claim CTA.
class _CardConfettiPainter extends CustomPainter {
  const _CardConfettiPainter({
    required this.progress,
    required this.particles,
  });

  final double progress;
  final List<_QuestConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.001 || progress >= 0.999) return;

    // Anchor burst slightly inset from top-right near the CTA button
    final Offset origin = Offset(size.width - 50, 22);

    for (final _QuestConfettiParticle p in particles) {
      if (progress < p.delay) continue;
      final double t = ((progress - p.delay) / (1.0 - p.delay)).clamp(0.0, 1.0);
      if (t >= 1.0) continue;

      final double distance = p.speed * t * 115.0;
      final double x = origin.dx + math.cos(p.angle) * distance;
      final double y = origin.dy +
          math.sin(p.angle) * distance +
          (p.gravity * t * t * 95.0);

      final double alpha = (1.0 - math.pow(t, 1.6)).clamp(0.0, 1.0);
      if (alpha <= 0.0) continue;

      final Paint paint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotationSpeed * t);

      if (p.isSparkle) {
        final Path star = Path();
        final double s = p.size;
        star.moveTo(0, -s);
        star.quadraticBezierTo(0, 0, s, 0);
        star.quadraticBezierTo(0, 0, 0, s);
        star.quadraticBezierTo(0, 0, -s, 0);
        star.quadraticBezierTo(0, 0, 0, -s);
        star.close();
        canvas.drawPath(star, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 1.3,
            height: p.size * 0.75,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CardConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
