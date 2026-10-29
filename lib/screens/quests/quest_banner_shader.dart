import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

/// Animated celestial banner shader with dynamic sheen, nebula backdrop,
/// and radial completion gauge for the Aion 2 Mobile Quests screen.
class QuestBannerShader extends StatefulWidget {
  const QuestBannerShader({
    super.key,
    required this.completionRate,
    required this.completedCount,
    required this.totalQuests,
    this.onTap,
  });

  final double completionRate;
  final int completedCount;
  final int totalQuests;
  final VoidCallback? onTap;

  @override
  State<QuestBannerShader> createState() => _QuestBannerShaderState();
}

class _QuestBannerShaderState extends State<QuestBannerShader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = (widget.completionRate.clamp(0.0, 1.0) * 100).round();
    final isFullyDone = widget.completionRate >= 1.0 && widget.totalQuests > 0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isFullyDone
                ? AppColors.success.withValues(alpha: 0.55)
                : const Color(0xFF6366F1).withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isFullyDone
                  ? AppColors.success.withValues(alpha: 0.22)
                  : const Color(0xFF6366F1).withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
            const BoxShadow(
              color: Color(0x66000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              // Celestial animated shader canvas
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _CelestialBannerPainter(
                        animationValue: _animCtrl.value,
                        isComplete: isFullyDone,
                      ),
                    );
                  },
                ),
              ),

              // Content Layout
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  children: [
                    // Left Column: Titles, Stats & Progress Bar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF818CF8), Color(0xFF6366F1)],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  'AION 2 EXPEDITIONS',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                              ),
                              if (widget.completedCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.card_giftcard_rounded,
                                        size: 11,
                                        color: Color(0xFF34D399),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${widget.completedCount} Ödül Hazır',
                                        style: const TextStyle(
                                          color: Color(0xFF34D399),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Görev İlerlemesi & Keşifler',
                            style: TextStyle(
                              color: Color(0xFFF1F5F9),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Custom Luminous Progress Bar
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final barWidth = constraints.maxWidth;
                              final fillWidth = (barWidth * widget.completionRate.clamp(0.0, 1.0));
                              return Container(
                                height: 8,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(99),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 0.8,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Container(
                                      width: fillWidth,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(99),
                                        gradient: LinearGradient(
                                          colors: isFullyDone
                                              ? const [Color(0xFF059669), Color(0xFF34D399)]
                                              : const [Color(0xFF6366F1), Color(0xFF38BDF8)],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (isFullyDone
                                                    ? const Color(0xFF34D399)
                                                    : const Color(0xFF38BDF8))
                                                .withValues(alpha: 0.4),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${widget.completedCount} / ${widget.totalQuests} Görev Hazır · %$pct Tamamlandı',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right: Radial Dial with Celestial Crest
                    _RadialDialGauge(
                      pct: pct,
                      completionRate: widget.completionRate,
                      isFullyDone: isFullyDone,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadialDialGauge extends StatelessWidget {
  const _RadialDialGauge({
    required this.pct,
    required this.completionRate,
    required this.isFullyDone,
  });

  final int pct;
  final double completionRate;
  final bool isFullyDone;

  @override
  Widget build(BuildContext context) {
    final ringColor = isFullyDone ? const Color(0xFF34D399) : const Color(0xFF38BDF8);

    return SizedBox(
      width: 66,
      height: 66,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background Glow
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ringColor.withValues(alpha: 0.12),
              boxShadow: [
                BoxShadow(
                  color: ringColor.withValues(alpha: 0.28),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          // Circular Progress Indicator
          SizedBox(
            width: 58,
            height: 58,
            child: CircularProgressIndicator(
              value: completionRate.clamp(0.0, 1.0),
              strokeWidth: 4.5,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(ringColor),
              strokeCap: StrokeCap.round,
            ),
          ),
          // Center Text
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '%$pct',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                isFullyDone ? 'Tam' : 'Keşif',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.7),
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the animated celestial sheen, nebula gradients,
/// and astral stardust particles.
class _CelestialBannerPainter extends CustomPainter {
  _CelestialBannerPainter({
    required this.animationValue,
    required this.isComplete,
  });

  final double animationValue;
  final bool isComplete;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Deep Space Nebula Gradient
    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isComplete
          ? const [
              Color(0xFF064E3B), // Deep emerald
              Color(0xFF0F172A), // Dark slate
              Color(0xFF042F2E), // Teal void
            ]
          : const [
              Color(0xFF1E1B4B), // Deep astral indigo
              Color(0xFF0F172A), // Midnight void
              Color(0xFF1E1035), // Dark nebula violet
            ],
      stops: const [0.0, 0.55, 1.0],
    );

    final bgPaint = Paint()..shader = baseGradient.createShader(rect);
    canvas.drawRect(rect, bgPaint);

    // 2. Swirling Nebula Glow Circles
    final glowPaint = Paint()..style = PaintingStyle.fill;

    // Violet/Emerald glow orb left
    glowPaint.shader = RadialGradient(
      colors: [
        (isComplete ? const Color(0xFF10B981) : const Color(0xFF818CF8))
            .withValues(alpha: 0.28),
        Colors.transparent,
      ],
      radius: 0.9,
    ).createShader(Rect.fromCircle(
      center: Offset(size.width * 0.15, size.height * 0.4),
      radius: size.width * 0.45,
    ));
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.4),
      size.width * 0.45,
      glowPaint,
    );

    // Cyan glow orb right
    glowPaint.shader = RadialGradient(
      colors: [
        (isComplete ? const Color(0xFF34D399) : const Color(0xFF38BDF8))
            .withValues(alpha: 0.22),
        Colors.transparent,
      ],
      radius: 0.9,
    ).createShader(Rect.fromCircle(
      center: Offset(size.width * 0.85, size.height * 0.6),
      radius: size.width * 0.4,
    ));
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.6),
      size.width * 0.4,
      glowPaint,
    );

    // 3. Stardust Motes
    final starPaint = Paint()..color = Colors.white;
    const starCount = 14;
    for (int i = 0; i < starCount; i++) {
      final seedX = ((i * 37) % 100) / 100.0;
      final seedY = ((i * 59) % 100) / 100.0;
      final x = seedX * size.width;
      final y = seedY * size.height;
      final twinkle = 0.3 + 0.7 * math.sin((animationValue * 2 * math.pi) + i * 1.3).abs();
      final radius = 0.8 + (i % 3) * 0.6;
      starPaint.color = Colors.white.withValues(alpha: twinkle * 0.65);
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }

    // 4. Diagonal Celestial Sheen Flare (Sweeps from left to right)
    final sweepProgress = (animationValue * 1.6) - 0.3; // -0.3 to 1.3
    final sheenStartX = sweepProgress * size.width;
    final sheenWidth = size.width * 0.35;

    final sheenShader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.transparent,
        (isComplete ? const Color(0xFF6EE7B7) : const Color(0xFFE0E7FF))
            .withValues(alpha: 0.0),
        (isComplete ? const Color(0xFF6EE7B7) : const Color(0xFFE0E7FF))
            .withValues(alpha: 0.16),
        (isComplete ? const Color(0xFF6EE7B7) : const Color(0xFFE0E7FF))
            .withValues(alpha: 0.0),
        Colors.transparent,
      ],
      stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
    ).createShader(
      Rect.fromLTWH(sheenStartX - sheenWidth * 0.5, 0, sheenWidth, size.height),
    );

    final sheenPaint = Paint()
      ..shader = sheenShader
      ..blendMode = BlendMode.screen;

    canvas.drawRect(
      Rect.fromLTWH(sheenStartX - sheenWidth * 0.5, 0, sheenWidth, size.height),
      sheenPaint,
    );

    // 5. Subtle Top Edge Luminous Highlight
    final borderTopPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          (isComplete ? const Color(0xFF34D399) : const Color(0xFF818CF8))
              .withValues(alpha: 0.45),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 1.5))
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(16, 0.6), Offset(size.width - 16, 0.6), borderTopPaint);
  }

  @override
  bool shouldRepaint(covariant _CelestialBannerPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isComplete != isComplete;
  }
}
