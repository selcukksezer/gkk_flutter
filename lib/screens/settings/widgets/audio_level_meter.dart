import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'settings_design.dart';

/// Glowing Sound Level Meter (VU / Frequency Equalizer)
///
/// Features dynamic LED bars, peak-hold indicator, Aion-2 neon glow bloom,
/// and live equalizer oscillation when audio is active.
class GlowingSoundLevelMeter extends StatefulWidget {
  const GlowingSoundLevelMeter({
    super.key,
    required this.volume,
    required this.accentColor,
    this.muted = false,
    this.barCount = 12,
    this.height = 20,
    this.showPeakIndicator = true,
  });

  final double volume; // 0.0 to 1.0
  final Color accentColor;
  final bool muted;
  final int barCount;
  final double height;
  final bool showPeakIndicator;

  @override
  State<GlowingSoundLevelMeter> createState() => _GlowingSoundLevelMeterState();
}

class _GlowingSoundLevelMeterState extends State<GlowingSoundLevelMeter>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!widget.muted && widget.volume > 0.01) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant GlowingSoundLevelMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool shouldAnimate = !widget.muted && widget.volume > 0.01;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _VuMeterPainter(
            volume: widget.muted ? 0.0 : widget.volume.clamp(0.0, 1.0),
            accentColor: widget.accentColor,
            barCount: widget.barCount,
            animationValue: _controller.value,
            showPeakIndicator: widget.showPeakIndicator,
            isMuted: widget.muted,
          ),
        );
      },
    );
  }
}

class _VuMeterPainter extends CustomPainter {
  _VuMeterPainter({
    required this.volume,
    required this.accentColor,
    required this.barCount,
    required this.animationValue,
    required this.showPeakIndicator,
    required this.isMuted,
  });

  final double volume;
  final Color accentColor;
  final int barCount;
  final double animationValue;
  final bool showPeakIndicator;
  final bool isMuted;

  @override
  void paint(Canvas canvas, Size size) {
    if (barCount <= 0 || size.width <= 0) return;

    final double totalSpacing = (barCount - 1) * 3.0;
    final double barWidth = (size.width - totalSpacing) / barCount;
    if (barWidth <= 1) return;

    final double phase = animationValue * 2 * math.pi;

    // Calculate how many base bars are lit
    final int litBarsCount = (volume * barCount).round();

    for (int i = 0; i < barCount; i++) {
      final double normalizedIdx = i / (barCount - 1);
      final double x = i * (barWidth + 3.0);

      // Natural frequency curve for EQ appearance (bell-shaped baseline heights)
      final double eqCurve = 0.55 + 0.45 * math.sin(normalizedIdx * math.pi);
      
      // Dynamic live pulse when active
      double dynamicFactor = 1.0;
      if (volume > 0.01 && !isMuted) {
        // Multi-frequency wave ripple
        final double wave1 = math.sin(phase + i * 0.6) * 0.18;
        final double wave2 = math.cos(phase * 1.5 + i * 0.3) * 0.12;
        dynamicFactor = (1.0 + wave1 + wave2).clamp(0.65, 1.35);
      }

      // Bar full physical height
      final double barFullHeight = (size.height * eqCurve).clamp(6.0, size.height);

      // Is this segment lit based on volume?
      final bool isLit = !isMuted && (i < litBarsCount);

      // Color gradation across frequency:
      // Lowest 65% = Accent color
      // Next 25% = Vibrant warning / highlight
      // Top 10% = Peak red/ruby
      Color barColor;
      if (normalizedIdx > 0.85) {
        barColor = SettingsPalette.ruby;
      } else if (normalizedIdx > 0.65) {
        barColor = SettingsPalette.coral;
      } else {
        barColor = accentColor;
      }

      final Rect barRect = Rect.fromLTWH(
        x,
        size.height - (isLit ? (barFullHeight * dynamicFactor).clamp(4.0, size.height) : 4.0),
        barWidth,
        isLit ? (barFullHeight * dynamicFactor).clamp(4.0, size.height) : 4.0,
      );

      final RRect roundedBar = RRect.fromRectAndRadius(
        barRect,
        const Radius.circular(2.5),
      );

      if (isLit) {
        // Outer neon glow bloom for active lit bars
        final Paint glowPaint = Paint()
          ..color = barColor.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
        canvas.drawRRect(roundedBar, glowPaint);

        // Core bright bar
        final Paint corePaint = Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[
              barColor.withValues(alpha: 0.85),
              Colors.white.withValues(alpha: 0.95),
            ],
            stops: const <double>[0.1, 1.0],
          ).createShader(barRect);
        canvas.drawRRect(roundedBar, corePaint);
      } else {
        // Dim unlit segment
        final Paint dimPaint = Paint()
          ..color = SettingsPalette.obsidian.withValues(alpha: 0.65)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(roundedBar, dimPaint);

        final Paint borderPaint = Paint()
          ..color = SettingsPalette.titanium.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8;
        canvas.drawRRect(roundedBar, borderPaint);
      }
    }

    // Optional glowing peak hold indicator
    if (showPeakIndicator && !isMuted && litBarsCount > 0) {
      final int peakIdx = (litBarsCount - 1).clamp(0, barCount - 1);
      final double peakX = peakIdx * (barWidth + 3.0);
      final Rect peakRect = Rect.fromLTWH(peakX, 0, barWidth, 2.0);
      final RRect peakRRect = RRect.fromRectAndRadius(
        peakRect,
        const Radius.circular(1.0),
      );

      final Paint peakGlow = Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawRRect(peakRRect, peakGlow);

      final Paint peakPaint = Paint()..color = Colors.white;
      canvas.drawRRect(peakRRect, peakPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VuMeterPainter oldDelegate) {
    return oldDelegate.volume != volume ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.isMuted != isMuted;
  }
}
