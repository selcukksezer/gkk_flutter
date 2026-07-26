import 'package:flutter/material.dart';

/// Full-screen dim overlay with a transparent hole over the target widget.
class TutorialSpotlightLayer extends StatelessWidget {
  const TutorialSpotlightLayer({
    super.key,
    required this.hole,
    this.borderRadius = 12,
    this.dimColor = const Color(0xBF000000),
  });

  final Rect hole;
  final double borderRadius;
  final Color dimColor;

  @override
  Widget build(BuildContext context) {
    // Visual only — hole taps must reach UI under the overlay.
    return IgnorePointer(
      child: CustomPaint(
        painter: _SpotlightPainter(
          hole: hole,
          borderRadius: borderRadius,
          dimColor: dimColor,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.hole,
    required this.borderRadius,
    required this.dimColor,
  });

  final Rect hole;
  final double borderRadius;
  final Color dimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Path full = Path()..addRect(Offset.zero & size);
    final RRect holeRRect = RRect.fromRectAndRadius(
      hole.inflate(4),
      Radius.circular(borderRadius),
    );
    final Path holePath = Path()..addRRect(holeRRect);
    final Path mask = Path.combine(PathOperation.difference, full, holePath);

    canvas.drawPath(mask, Paint()..color = dimColor);

    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFFFFB800).withValues(alpha: 0.85);
    canvas.drawRRect(holeRRect, border);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.hole != hole ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.dimColor != dimColor;
  }
}
