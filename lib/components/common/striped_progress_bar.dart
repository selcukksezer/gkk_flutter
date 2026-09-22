import 'package:flutter/material.dart';

import '../../core/utils/player_health.dart';
import '../../theme/app_colors.dart';

const List<Color> defaultXpBarGradient = <Color>[
  AppColors.cyberFuchsia,
  AppColors.toxicNeon,
];

/// Burgundy-forward palette for the top-bar health vitals bar.
abstract final class HealthBarColors {
  static const Color track = Color(0xFF1A0C10);
  static const Color trackInner = Color(0xFF2A141A);
  static const Color border = Color(0xFF6E2A3A);
  static const Color label = Color(0xFFE8899C);
  static const Color labelMuted = Color(0xFFCFA0AA);
  static const Color stripe = Color(0xFFFFE8EE);

  static List<Color> fillGradient(PlayerHealthStatus status) {
    return switch (status) {
      PlayerHealthStatus.critical => const <Color>[
        Color(0xFF3A0A12),
        Color(0xFF8B1834),
        Color(0xFFD6284A),
        Color(0xFFFF4D6D),
      ],
      PlayerHealthStatus.wounded => const <Color>[
        Color(0xFF321018),
        Color(0xFF6E2236),
        Color(0xFF9E3348),
        Color(0xFFC85A52),
      ],
      PlayerHealthStatus.recovering => const <Color>[
        Color(0xFF2E1018),
        Color(0xFF5C1E30),
        Color(0xFF8B2D42),
        Color(0xFFAD3D55),
      ],
      _ => const <Color>[
        Color(0xFF280E14),
        Color(0xFF5A1A2C),
        Color(0xFF7F2438),
        Color(0xFFA8324C),
      ],
    };
  }

  static Color glow(PlayerHealthStatus status) {
    return switch (status) {
      PlayerHealthStatus.critical => const Color(0xFFFF5C7A),
      PlayerHealthStatus.wounded => const Color(0xFFE06B62),
      _ => const Color(0xFFCF4A66),
    };
  }
}

class StripedProgressBarPainter extends CustomPainter {
  StripedProgressBarPainter({
    required this.percent,
    this.gradientColors,
  });

  final double percent;
  final List<Color>? gradientColors;

  @override
  void paint(Canvas canvas, Size size) {
    const Radius trackRadius = Radius.circular(6);

    final Paint trackPaint = Paint()
      ..color = const Color(0xFF1E2633)
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final RRect trackRRect =
        RRect.fromRectAndRadius(Offset.zero & size, trackRadius);
    canvas.drawRRect(trackRRect, trackPaint);
    canvas.drawRRect(trackRRect, borderPaint);

    if (percent <= 0) return;

    final double fillWidth = size.width * percent;
    final Rect fillRect = Rect.fromLTWH(0, 0, fillWidth, size.height);
    final RRect fillRRect = RRect.fromRectAndRadius(fillRect, trackRadius);

    final List<Color> colors = gradientColors ?? defaultXpBarGradient;

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(colors: colors).createShader(fillRect);

    canvas.save();
    canvas.clipRRect(fillRRect);
    canvas.drawRect(fillRect, fillPaint);

    final Paint stripePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (double i = -size.height; i < fillWidth; i += 10) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        stripePaint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StripedProgressBarPainter oldDelegate) {
    return oldDelegate.percent != percent ||
        oldDelegate.gradientColors != gradientColors;
  }
}

/// Rich burgundy health bar with glass highlight and soft glow.
class HealthStripedBarPainter extends CustomPainter {
  HealthStripedBarPainter({
    required this.percent,
    required this.status,
  });

  final double percent;
  final PlayerHealthStatus status;

  @override
  void paint(Canvas canvas, Size size) {
    const Radius trackRadius = Radius.circular(6);
    final RRect trackRRect =
        RRect.fromRectAndRadius(Offset.zero & size, trackRadius);

    final Paint trackPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[HealthBarColors.trackInner, HealthBarColors.track],
      ).createShader(trackRRect.outerRect);
    canvas.drawRRect(trackRRect, trackPaint);

    final Paint borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          HealthBarColors.border.withValues(alpha: 0.65),
          HealthBarColors.border.withValues(alpha: 0.28),
        ],
      ).createShader(trackRRect.outerRect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(trackRRect, borderPaint);

    if (percent <= 0) return;

    final double fillWidth = size.width * percent.clamp(0.0, 1.0);
    final Rect fillRect = Rect.fromLTWH(0, 0, fillWidth, size.height);
    final RRect fillRRect = RRect.fromRectAndRadius(fillRect, trackRadius);

    final List<Color> gradient = HealthBarColors.fillGradient(status);

    canvas.save();
    canvas.clipRRect(fillRRect);

    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: gradient,
        stops: List<double>.generate(
          gradient.length,
          (int index) => index / (gradient.length - 1),
        ),
      ).createShader(fillRect);
    canvas.drawRect(fillRect, fillPaint);

    final Paint sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.28),
          Colors.white.withValues(alpha: 0.06),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.42, 1.0],
      ).createShader(fillRect);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, fillWidth, size.height * 0.55),
      sheenPaint,
    );

    final Paint stripePaint = Paint()
      ..color = HealthBarColors.stripe.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    for (double i = -size.height; i < fillWidth; i += 9) {
      canvas.drawLine(
        Offset(i, size.height),
        Offset(i + size.height, 0),
        stripePaint,
      );
    }

    final Paint pulsePaint = Paint()
      ..color = HealthBarColors.glow(status).withValues(alpha: 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawRRect(fillRRect, pulsePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HealthStripedBarPainter oldDelegate) {
    return oldDelegate.percent != percent || oldDelegate.status != status;
  }
}
