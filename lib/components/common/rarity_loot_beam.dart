import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/graphics_quality_service.dart';
import '../../models/item_model.dart';

/// Diablo / ARPG-style skyward rarity light pillar (`LootBeam`) + ground rune ring
/// + rising stardust motes for `rare`, `epic`, `legendary`, and `mythic` drops!
///
/// - Automatically scales with [GraphicsQualityService] (`Low` tier draws crisp
///   zero-blur geometric pillar; `Medium+` animates beam pulse and rising sparks).
/// - Safe for `tester.pumpAndSettle()` in widget tests unless [debugAnimateInTests]
///   is enabled.
class RarityLootBeamOverlay extends StatefulWidget {
  const RarityLootBeamOverlay({
    super.key,
    required this.rarity,
    this.height = 190,
    this.width = 220,
    this.enhancementLevel = 0,
    this.child,
  });

  final Rarity rarity;
  final double height;
  final double width;
  final int enhancementLevel;
  final Widget? child;

  @visibleForTesting
  static bool debugAnimateInTests = false;

  static bool shouldShowBeam(Rarity rarity, {int enhancementLevel = 0}) {
    return rarity.index >= Rarity.rare.index || enhancementLevel >= 7;
  }

  @override
  State<RarityLootBeamOverlay> createState() => _RarityLootBeamOverlayState();
}

class _RarityLootBeamOverlayState extends State<RarityLootBeamOverlay>
    with SingleTickerProviderStateMixin {
  AnimationController? _ctrl;

  static bool get _isTestBinding {
    try {
      return WidgetsBinding.instance.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    GraphicsQualityService.instance.addListener(_syncAnimation);
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant RarityLootBeamOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final bool qualifies = RarityLootBeamOverlay.shouldShowBeam(
      widget.rarity,
      enhancementLevel: widget.enhancementLevel,
    );
    final bool shouldTick = qualifies &&
        !GraphicsQualityService.instance.profile.isLow &&
        (!_isTestBinding || RarityLootBeamOverlay.debugAnimateInTests);

    if (shouldTick) {
      _ctrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2400),
      );
      if (!_ctrl!.isAnimating) {
        _ctrl!.repeat();
      }
    } else {
      _ctrl?.stop();
    }
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_syncAnimation);
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!RarityLootBeamOverlay.shouldShowBeam(
      widget.rarity,
      enhancementLevel: widget.enhancementLevel,
    )) {
      return widget.child ?? const SizedBox.shrink();
    }

    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final Color beamColor = getRarityColor(widget.rarity);

    final Widget beamLayer = IgnorePointer(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: _ctrl != null && _ctrl!.isAnimating
            ? AnimatedBuilder(
                animation: _ctrl!,
                builder: (BuildContext context, _) => CustomPaint(
                  key: const ValueKey<String>('rarity_loot_beam_paint'),
                  painter: RarityLootBeamPainter(
                    rarity: widget.rarity,
                    beamColor: beamColor,
                    phase: _ctrl!.value,
                    isLowTier: gfx.isLow,
                  ),
                ),
              )
            : CustomPaint(
                key: const ValueKey<String>('rarity_loot_beam_paint'),
                painter: RarityLootBeamPainter(
                  rarity: widget.rarity,
                  beamColor: beamColor,
                  phase: 0.35,
                  isLowTier: gfx.isLow,
                ),
              ),
      ),
    );

    if (widget.child == null) return beamLayer;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          bottom: 4,
          child: beamLayer,
        ),
        widget.child!,
      ],
    );
  }
}

class RarityLootBeamPainter extends CustomPainter {
  const RarityLootBeamPainter({
    required this.rarity,
    required this.beamColor,
    required this.phase,
    required this.isLowTier,
  });

  final Rarity rarity;
  final Color beamColor;
  final double phase;
  final bool isLowTier;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final double cx = size.width * 0.5;
    final double baseY = size.height * 0.86;
    final double pulse = 0.88 + 0.12 * math.sin(phase * math.pi * 2);
    final double tierScale = switch (rarity) {
      Rarity.mythic => 1.32,
      Rarity.legendary => 1.18,
      Rarity.epic => 1.0,
      _ => 0.78,
    };

    final double halfWidth = (22.0 * tierScale * pulse).clamp(14.0, size.width * 0.38);

    // 1. Ground shock-ring & rune disc
    final Rect groundDisc = Rect.fromCenter(
      center: Offset(cx, baseY),
      width: halfWidth * 3.5,
      height: halfWidth * 0.92,
    );
    final Paint discPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.52),
          beamColor.withValues(alpha: 0.44),
          beamColor.withValues(alpha: 0.0),
        ],
        stops: const <double>[0.0, 0.48, 1.0],
      ).createShader(groundDisc);
    canvas.drawOval(groundDisc, discPaint);

    final Paint runeRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = rarity.index >= Rarity.legendary.index ? 1.8 : 1.2
      ..color = beamColor.withValues(alpha: 0.78);
    canvas.drawOval(groundDisc.deflate(4.0), runeRing);

    // 2. Skyward tapered pillar (outer aura + inner white-hot core)
    final Path outerPillar = Path()
      ..moveTo(cx - halfWidth, baseY)
      ..lineTo(cx - halfWidth * 0.38, 0)
      ..lineTo(cx + halfWidth * 0.38, 0)
      ..lineTo(cx + halfWidth, baseY)
      ..close();

    final Rect beamBounds = Rect.fromLTWH(cx - halfWidth, 0, halfWidth * 2, baseY);
    final Paint outerPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        stops: const <double>[0.0, 0.28, 0.72, 1.0],
        colors: <Color>[
          beamColor.withValues(alpha: 0.62),
          beamColor.withValues(alpha: 0.36),
          beamColor.withValues(alpha: 0.12),
          Colors.transparent,
        ],
      ).createShader(beamBounds);
    canvas.drawPath(outerPillar, outerPaint);

    final double coreHalfW = halfWidth * 0.30;
    final Rect coreRect = Rect.fromLTWH(
      cx - coreHalfW,
      size.height * 0.06,
      coreHalfW * 2,
      baseY - size.height * 0.06,
    );
    final Paint corePaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.85),
          beamColor.withValues(alpha: 0.55),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.45, 1.0],
      ).createShader(coreRect);
    canvas.drawRect(coreRect, corePaint);

    if (isLowTier) return;

    // 3. Rising stardust sparks & Mythic/Legendary twin solar rays
    if (rarity.index >= Rarity.legendary.index) {
      final Paint flareRay = Paint()
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.62 * pulse);
      canvas.drawLine(
        Offset(cx - halfWidth * 1.6, baseY),
        Offset(cx + halfWidth * 1.6, baseY),
        flareRay,
      );
    }

    final int moteCount = rarity.index >= Rarity.legendary.index ? 10 : 6;
    final Paint motePaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < moteCount; i++) {
      final double seed = (i * 0.173) % 1.0;
      final double progress = (phase + seed) % 1.0;
      final double y = baseY - progress * (baseY * 0.92);
      final double sway = math.sin(progress * math.pi * 3.0 + i * 1.4) *
          halfWidth *
          (0.65 - progress * 0.35);
      final double alpha = (1.0 - progress) * 0.85;
      motePaint.color = (i.isEven ? Colors.white : beamColor)
          .withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.drawCircle(
        Offset(cx + sway, y),
        i.isEven ? 2.1 : 1.5,
        motePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RarityLootBeamPainter oldDelegate) {
    return (oldDelegate.phase - phase).abs() > 0.005 ||
        oldDelegate.rarity != rarity ||
        oldDelegate.isLowTier != isLowTier;
  }
}
