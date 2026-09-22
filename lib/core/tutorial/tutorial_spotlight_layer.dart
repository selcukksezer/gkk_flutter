import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Full-screen dim overlay with an animated, glowing hole over the target.
///
/// Visual katman — dokunuşlar deliğin altındaki UI'a ulaşmalı, bu yüzden
/// tamamı [IgnorePointer] içindedir.
class TutorialSpotlightLayer extends StatefulWidget {
  const TutorialSpotlightLayer({
    super.key,
    required this.hole,
    this.borderRadius = 12,
    this.dimColor = const Color(0xCC05070D),
    this.accent = AppColors.liquidGold,
  });

  final Rect hole;
  final double borderRadius;
  final Color dimColor;
  final Color accent;

  @override
  State<TutorialSpotlightLayer> createState() => _TutorialSpotlightLayerState();
}

class _TutorialSpotlightLayerState extends State<TutorialSpotlightLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (BuildContext context, Widget? _) {
          return CustomPaint(
            painter: _SpotlightPainter(
              hole: widget.hole,
              borderRadius: widget.borderRadius,
              dimColor: widget.dimColor,
              accent: widget.accent,
              pulse: _pulse.value,
            ),
            child: const SizedBox.expand(),
          );
        },
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({
    required this.hole,
    required this.borderRadius,
    required this.dimColor,
    required this.accent,
    required this.pulse,
  });

  final Rect hole;
  final double borderRadius;
  final Color dimColor;
  final Color accent;

  /// 0..1 döngüsel nabız değeri.
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect holeRRect = RRect.fromRectAndRadius(
      hole.inflate(4),
      Radius.circular(borderRadius),
    );

    // Karartma maskesi
    final Path full = Path()..addRect(Offset.zero & size);
    final Path holePath = Path()..addRRect(holeRRect);
    final Path mask = Path.combine(PathOperation.difference, full, holePath);
    canvas.drawPath(mask, Paint()..color = dimColor);

    // Soft ring without MaskFilter.blur — blur → Impeller SaveLayer → SimMetal crash.
    final Paint innerGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = accent.withValues(alpha: 0.28);
    canvas.drawRRect(holeRRect, innerGlow);

    // Sabit çerçeve
    final Paint border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = accent.withValues(alpha: 0.9);
    canvas.drawRRect(holeRRect, border);

    // Genişleyip sönen nabız halkası
    final double ringSpread = 4 + pulse * 12;
    final double ringOpacity = (1 - pulse) * 0.55;
    if (ringOpacity > 0.01) {
      final RRect ringRRect = RRect.fromRectAndRadius(
        hole.inflate(4 + ringSpread),
        Radius.circular(borderRadius + ringSpread * 0.6),
      );
      final Paint ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: ringOpacity);
      canvas.drawRRect(ringRRect, ring);
    }

    // Köşe vurguları — delikle aynı inset
    final Paint corner = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = accent;
    const double cLen = 14;
    final Rect r = holeRRect.outerRect;
    canvas.drawLine(r.topLeft + const Offset(0, cLen), r.topLeft, corner);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(cLen, 0), corner);
    canvas.drawLine(
        r.bottomRight - const Offset(0, cLen), r.bottomRight, corner);
    canvas.drawLine(
        r.bottomRight, r.bottomRight - const Offset(cLen, 0), corner);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.hole != hole ||
        oldDelegate.pulse != pulse ||
        oldDelegate.accent != accent ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.dimColor != dimColor;
  }
}
