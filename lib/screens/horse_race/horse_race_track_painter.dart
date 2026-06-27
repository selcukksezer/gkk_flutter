import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class HorseRaceTrackPainter extends CustomPainter {
  HorseRaceTrackPainter({
    required this.laneCount,
    required this.laneColors,
    this.scrollOffset = 0,
    this.raceProgress = 0,
  });

  final int laneCount;
  final List<Color> laneColors;
  final double scrollOffset;
  final double raceProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;

    final Paint sky = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF1A2F4A), Color(0xFF0B1628)],
      ).createShader(bounds);
    canvas.drawRect(bounds, sky);

    final double laneHeight = size.height / math.max(laneCount, 1);

    for (int i = 0; i < laneCount; i++) {
      final double top = i * laneHeight;
      final Color laneColor = i < laneColors.length ? laneColors[i] : AppColors.borderDefault;
      final Rect laneRect = Rect.fromLTWH(0, top, size.width, laneHeight);

      final Paint lanePaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            const Color(0xFF1B3A2F).withValues(alpha: 0.95),
            const Color(0xFF24553F).withValues(alpha: 0.9),
          ],
        ).createShader(laneRect);
      canvas.drawRect(laneRect, lanePaint);

      final Paint stripePaint = Paint()..color = Colors.white.withValues(alpha: 0.04);
      for (double x = -scrollOffset % 40; x < size.width; x += 40) {
        canvas.drawRect(Rect.fromLTWH(x, top + 6, 18, laneHeight - 12), stripePaint);
      }

      final Paint borderPaint = Paint()
        ..color = laneColor.withValues(alpha: 0.35)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(0, top), Offset(size.width, top), borderPaint);
    }

    final double finishX = size.width * 0.90;
    final Paint finishPaint = Paint()
      ..shader = LinearGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.55 + raceProgress * 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(finishX - 5, 0, 10, size.height));
    canvas.drawRect(Rect.fromLTWH(finishX - 5, 0, 10, size.height), finishPaint);

    for (int row = 0; row < 8; row++) {
      final Paint checker = Paint()
        ..color = (row % 2 == 0 ? Colors.white : Colors.black).withValues(alpha: 0.12);
      canvas.drawRect(
        Rect.fromLTWH(finishX - 5, row * (size.height / 8), 5, size.height / 8),
        checker,
      );
      canvas.drawRect(
        Rect.fromLTWH(finishX, row * (size.height / 8), 5, size.height / 8),
        checker,
      );
    }
  }

  @override
  bool shouldRepaint(covariant HorseRaceTrackPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.laneCount != laneCount ||
        oldDelegate.raceProgress != raceProgress;
  }
}
