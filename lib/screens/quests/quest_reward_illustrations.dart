import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Categories of authentic quest rewards in Aion 2 Mobile.
enum QuestRewardType {
  gold,
  gem,
  xp,
  material,
  bpp,
  energy,
}

/// Authentic vector-rendered reward illustration widget.
class QuestRewardIllustration extends StatelessWidget {
  const QuestRewardIllustration({
    super.key,
    required this.type,
    this.size = 28,
    this.showGlow = true,
  });

  final QuestRewardType type;
  final double size;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RewardVectorPainter(type: type, showGlow: showGlow),
      ),
    );
  }
}

/// Compact glassmorphism chip displaying a reward icon and its quantity.
class QuestRewardPill extends StatelessWidget {
  const QuestRewardPill({
    super.key,
    required this.type,
    required this.amount,
    this.suffix,
    this.customColor,
  });

  final QuestRewardType type;
  final String amount;
  final String? suffix;
  final Color? customColor;

  Color get _baseColor =>
      customColor ??
      switch (type) {
        QuestRewardType.gold => const Color(0xFFFBBF24),
        QuestRewardType.gem => const Color(0xFF06D0D8),
        QuestRewardType.xp => const Color(0xFF818CF8),
        QuestRewardType.material => const Color(0xFFA855F7),
        QuestRewardType.bpp => const Color(0xFFF59E0B),
        QuestRewardType.energy => const Color(0xFFFB923C),
      };

  @override
  Widget build(BuildContext context) {
    final color = _baseColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          QuestRewardIllustration(type: type, size: 15, showGlow: false),
          const SizedBox(width: 4),
          Text(
            suffix != null ? '$amount $suffix' : amount,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detailed large reward presentation card used in modal sheets.
class QuestRewardDetailedCard extends StatelessWidget {
  const QuestRewardDetailedCard({
    super.key,
    required this.type,
    required this.amount,
    required this.title,
    this.subtitle,
  });

  final QuestRewardType type;
  final String amount;
  final String title;
  final String? subtitle;

  Color get _accentColor => switch (type) {
        QuestRewardType.gold => const Color(0xFFFBBF24),
        QuestRewardType.gem => const Color(0xFF06D0D8),
        QuestRewardType.xp => const Color(0xFF818CF8),
        QuestRewardType.material => const Color(0xFFA855F7),
        QuestRewardType.bpp => const Color(0xFFF59E0B),
        QuestRewardType.energy => const Color(0xFFFB923C),
      };

  @override
  Widget build(BuildContext context) {
    final color = _accentColor;
    return Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131A2B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withValues(alpha: 0.38),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 0.8,
              ),
            ),
            child: QuestRewardIllustration(type: type, size: 26, showGlow: true),
          ),
          const SizedBox(height: 6),
          Text(
            amount,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering each reward type with vector paths, gradients,
/// specular highlights, and Aion 2 celestial fantasy aesthetics.
class _RewardVectorPainter extends CustomPainter {
  _RewardVectorPainter({required this.type, required this.showGlow});

  final QuestRewardType type;
  final bool showGlow;

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case QuestRewardType.gold:
        _drawGoldCoin(canvas, size);
        break;
      case QuestRewardType.gem:
        _drawAstralGem(canvas, size);
        break;
      case QuestRewardType.xp:
        _drawExperienceScroll(canvas, size);
        break;
      case QuestRewardType.material:
        _drawCosmicMaterial(canvas, size);
        break;
      case QuestRewardType.bpp:
        _drawBattlePassEmblem(canvas, size);
        break;
      case QuestRewardType.energy:
        _drawStarlightEnergy(canvas, size);
        break;
    }
  }

  void _drawGoldCoin(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.44;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFBBF24).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center, radius + 2, glowPaint);
    }

    // Outer Coin Rim
    final rimPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFDE68A), Color(0xFFD97706), Color(0xFF92400E)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, rimPaint);

    // Inner Coin Face
    final innerRadius = radius * 0.82;
    final innerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [Color(0xFFF59E0B), Color(0xFFB45309)],
      ).createShader(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.drawCircle(center, innerRadius, innerPaint);

    // Inner Crest / Star Symbol
    final starPath = Path();
    const spikes = 4;
    final outerR = innerRadius * 0.65;
    final innerR = innerRadius * 0.28;
    for (int i = 0; i < spikes * 2; i++) {
      final r = i.isEven ? outerR : innerR;
      final angle = (i * math.pi / spikes) - (math.pi / 2);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();

    final starPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFEF3C7), Color(0xFFFCD34D)],
      ).createShader(Rect.fromCircle(center: center, radius: outerR));
    canvas.drawPath(starPath, starPaint);

    // Specular Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: innerRadius * 0.95),
      math.pi * 1.1,
      math.pi * 0.7,
      false,
      highlightPaint,
    );
  }

  void _drawAstralGem(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFF06D0D8).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.45, glowPaint);
    }

    // Faceted Gem Shape (Classic Brilliant Cut)
    final topY = h * 0.16;
    final tableLeft = w * 0.28;
    final tableRight = w * 0.72;
    final shoulderY = h * 0.42;
    final bottomY = h * 0.88;

    // Center Crown
    final crownPath = Path()
      ..moveTo(tableLeft, topY)
      ..lineTo(tableRight, topY)
      ..lineTo(w * 0.9, shoulderY)
      ..lineTo(w * 0.1, shoulderY)
      ..close();

    final crownPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE0F2FE), Color(0xFF38BDF8)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(crownPath, crownPaint);

    // Lower Pavilion
    final pavilionPath = Path()
      ..moveTo(w * 0.1, shoulderY)
      ..lineTo(w * 0.9, shoulderY)
      ..lineTo(w * 0.5, bottomY)
      ..close();

    final pavilionPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0284C7), Color(0xFF0369A1), Color(0xFF0C4A6E)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(pavilionPath, pavilionPaint);

    // Center Facet Lines
    final facetPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;

    canvas.drawLine(Offset(tableLeft, topY), Offset(w * 0.35, shoulderY), facetPaint);
    canvas.drawLine(Offset(tableRight, topY), Offset(w * 0.65, shoulderY), facetPaint);
    canvas.drawLine(Offset(w * 0.35, shoulderY), Offset(w * 0.5, bottomY), facetPaint);
    canvas.drawLine(Offset(w * 0.65, shoulderY), Offset(w * 0.5, bottomY), facetPaint);

    // Specular Glint
    final glintPaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(tableLeft + 2, topY + 2), 1.2, glintPaint);
  }

  void _drawExperienceScroll(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFF818CF8).withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.45, glowPaint);
    }

    // Scroll Body (Diagonal angled ancient scroll)
    final scrollPath = Path()
      ..moveTo(w * 0.22, h * 0.22)
      ..lineTo(w * 0.72, h * 0.14)
      ..quadraticBezierTo(w * 0.86, h * 0.2, w * 0.82, h * 0.76)
      ..lineTo(w * 0.32, h * 0.84)
      ..quadraticBezierTo(w * 0.18, h * 0.78, w * 0.22, h * 0.22)
      ..close();

    final scrollPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFFD97706)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(scrollPath, scrollPaint);

    // Arcane Ribbon Binding
    final ribbonPath = Path()
      ..moveTo(w * 0.46, h * 0.18)
      ..lineTo(w * 0.58, h * 0.16)
      ..lineTo(w * 0.56, h * 0.82)
      ..lineTo(w * 0.44, h * 0.84)
      ..close();

    final ribbonPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF818CF8), Color(0xFF4F46E5)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(ribbonPath, ribbonPaint);

    // Celestial Seal in ribbon center
    final sealPaint = Paint()..color = const Color(0xFFFCD34D);
    canvas.drawCircle(Offset(w * 0.51, h * 0.5), w * 0.09, sealPaint);

    // Scroll Edges
    final edgePaint = Paint()
      ..color = const Color(0xFF92400E).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(scrollPath, edgePaint);
  }

  void _drawCosmicMaterial(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.42;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFFA855F7).withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(center, r + 2, glowPaint);
    }

    // Hexagonal Runic Shard
    final hexPath = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3) - (math.pi / 6);
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        hexPath.moveTo(x, y);
      } else {
        hexPath.lineTo(x, y);
      }
    }
    hexPath.close();

    final hexPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFE9D5FF), Color(0xFFA855F7), Color(0xFF581C87)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawPath(hexPath, hexPaint);

    // Inner Crystal Node
    final innerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, r * 0.48, innerPaint);

    final corePaint = Paint()..color = const Color(0xFFFAF5FF);
    canvas.drawCircle(center, r * 0.22, corePaint);
  }

  void _drawBattlePassEmblem(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44, glowPaint);
    }

    // Aion Shield Crest
    final shieldPath = Path()
      ..moveTo(w * 0.5, h * 0.12)
      ..lineTo(w * 0.88, h * 0.28)
      ..quadraticBezierTo(w * 0.86, h * 0.65, w * 0.5, h * 0.88)
      ..quadraticBezierTo(w * 0.14, h * 0.65, w * 0.12, h * 0.28)
      ..close();

    final shieldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDE68A), Color(0xFFD97706), Color(0xFF78350F)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(shieldPath, shieldPaint);

    // Inner Emblem Star / Wing
    final wingPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final starCenter = Offset(w * 0.5, h * 0.44);
    canvas.drawCircle(starCenter, w * 0.14, wingPaint);
  }

  void _drawStarlightEnergy(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    if (showGlow) {
      final glowPaint = Paint()
        ..color = const Color(0xFFFB923C).withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(w / 2, h / 2), w * 0.44, glowPaint);
    }

    // Lightning Bolt
    final boltPath = Path()
      ..moveTo(w * 0.58, h * 0.12)
      ..lineTo(w * 0.26, h * 0.52)
      ..lineTo(w * 0.48, h * 0.52)
      ..lineTo(w * 0.40, h * 0.88)
      ..lineTo(w * 0.74, h * 0.44)
      ..lineTo(w * 0.52, h * 0.44)
      ..close();

    final boltPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFEF08A), Color(0xFFF97316)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(boltPath, boltPaint);

    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawPath(boltPath, edgePaint);
  }

  @override
  bool shouldRepaint(covariant _RewardVectorPainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.showGlow != showGlow;
  }
}
