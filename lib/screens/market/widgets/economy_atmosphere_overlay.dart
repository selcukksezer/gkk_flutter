import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/engine/adaptive_quality_scaler.dart';
import '../../../theme/app_colors.dart';
import '../../crafting/widgets/crafting_forge_effects.dart';

/// 2027 Aion 2 Mobile — Luxury Dark-Fantasy Economy Atmosphere Overlay.
///
/// Combines:
/// 1. Blacksmith embers rising from the forge (convection physics, air drag,
///    thermal decay from incandescent white to flame gold to ember red).
/// 2. Luxury traveling gold shimmer sweeps across dark obsidian panels.
/// 3. Ambient atmospheric vignette with subtle radial gold and molten amber glow.
/// 4. Adaptive quality scaling: adjusts particle counts and skips heavy blur
///    effects on low-end hardware tiers (Eco/Low).
class EconomyAtmosphereOverlay extends StatelessWidget {
  const EconomyAtmosphereOverlay({
    super.key,
    required this.child,
    this.heatIntensity = 0.25,
    this.particleCount,
    this.showEmbers = true,
    this.showGoldShimmer = true,
    this.showVignette = true,
    this.shimmerColor = AppColors.liquidGold,
  });

  final Widget child;
  final double heatIntensity;
  final int? particleCount;
  final bool showEmbers;
  final bool showGoldShimmer;
  final bool showVignette;
  final Color shimmerColor;

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    // 1. Blacksmith Embers Layer
    if (showEmbers) {
      content = ForgeEmbersOverlay(
        heatIntensity: heatIntensity,
        particleCount: particleCount,
        child: content,
      );
    }

    // 2. Gold Shimmer & Ambient Vignette Layer
    if (showGoldShimmer || showVignette) {
      content = Stack(
        children: <Widget>[
          content,
          if (showVignette)
            const Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: _EconomyVignetteLayer(),
                ),
              ),
            ),
          if (showGoldShimmer)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: _EconomyGoldShimmerSweep(color: shimmerColor),
                ),
              ),
            ),
        ],
      );
    }

    return content;
  }
}

/// Atmospheric dark fantasy radial vignette with deep obsidian edges
/// and subtle molten amber glow at the bottom.
class _EconomyVignetteLayer extends StatelessWidget {
  const _EconomyVignetteLayer();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(
      painter: _EconomyVignettePainter(),
    );
  }
}

class _EconomyVignettePainter extends CustomPainter {
  const _EconomyVignettePainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Top-down dark fantasy shadow
    final Rect topRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.25);
    final Paint topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          AppColors.carbonVoid.withValues(alpha: 0.45),
          Colors.transparent,
        ],
      ).createShader(topRect);
    canvas.drawRect(topRect, topPaint);

    // Bottom blacksmith hearth molten reflection
    final Rect bottomRect = Rect.fromLTWH(
      0,
      size.height * 0.65,
      size.width,
      size.height * 0.35,
    );
    final Paint bottomPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, 1.0),
        radius: 1.1,
        colors: <Color>[
          const Color(0xFFE08A00).withValues(alpha: 0.08),
          const Color(0xFF993D00).withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(bottomRect);
    canvas.drawRect(bottomRect, bottomPaint);
  }

  @override
  bool shouldRepaint(covariant _EconomyVignettePainter oldDelegate) => false;
}

/// Periodic travelling luxury gold shimmer sweep across the screen surface.
class _EconomyGoldShimmerSweep extends StatefulWidget {
  const _EconomyGoldShimmerSweep({
    required this.color,
  });

  final Color color;

  @override
  State<_EconomyGoldShimmerSweep> createState() =>
      _EconomyGoldShimmerSweepState();
}

class _EconomyGoldShimmerSweepState extends State<_EconomyGoldShimmerSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    )..repeat();
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
          painter: _EconomyShimmerPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _EconomyShimmerPainter extends CustomPainter {
  const _EconomyShimmerPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Only sweep between 0.15 and 0.85 of the timeline to provide natural pauses
    final double activeT = ((progress - 0.15) / 0.55).clamp(0.0, 1.0);
    if (activeT <= 0.0 || activeT >= 1.0) return;

    final double sweepX =
        -size.width * 0.5 + activeT * (size.width * 2.0);
    final double bandWidth = size.width * 0.45;

    final Rect rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final Paint shimmerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          Colors.transparent,
          color.withValues(alpha: 0.02),
          color.withValues(alpha: 0.09),
          Colors.white.withValues(alpha: 0.12),
          color.withValues(alpha: 0.09),
          color.withValues(alpha: 0.02),
          Colors.transparent,
        ],
        stops: const <double>[
          0.0,
          0.30,
          0.46,
          0.50,
          0.54,
          0.70,
          1.0,
        ],
        transform: _SlantedGradientTransform(sweepX / size.width),
      ).createShader(rect);

    canvas.drawRect(rect, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant _EconomyShimmerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _SlantedGradientTransform extends GradientTransform {
  const _SlantedGradientTransform(this.offsetX);

  final double offsetX;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.identity()
      ..translate(bounds.width * offsetX, 0.0)
      ..rotateZ(-math.pi / 7);
  }
}

/// Reusable Luxury Gold Shimmer Card Border decorator.
class LuxuryGoldShimmerBorder extends StatelessWidget {
  const LuxuryGoldShimmerBorder({
    super.key,
    required this.child,
    this.borderRadius = 16.0,
    this.borderWidth = 1.2,
    this.shimmerColor = AppColors.liquidGold,
  });

  final Widget child;
  final double borderRadius;
  final double borderWidth;
  final Color shimmerColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: shimmerColor.withValues(alpha: 0.35),
          width: borderWidth,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shimmerColor.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.carbonVoid.withValues(alpha: 0.75),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
