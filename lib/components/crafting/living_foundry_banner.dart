import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/app_haptics.dart';
import '../../core/services/game_sfx_service.dart';
import '../../core/services/graphics_quality_service.dart';

/// V15 Pack 5: Living 2.5D Master Blacksmith & Royal Production Foundry Banner!
///
/// Renders `assets/v15/master_foundry_furnace_bg.jpg` with downsampled [ResizeImage],
/// flowing molten gold channel ripples, rising forge embers, and an interactive
/// `🔥 Körüğü Ateşle` bellows spark burst. Stops idle continuous tickers on `Low` tier.
class LivingFoundryBanner extends StatefulWidget {
  const LivingFoundryBanner({
    super.key = const Key('living_foundry_banner'),
    required this.title,
    required this.subtitle,
    required this.statusBadge,
    this.isProducing = false,
    this.compact = false,
  });

  final String title;
  final String subtitle;
  final String statusBadge;
  final bool isProducing;
  final bool compact;

  @override
  State<LivingFoundryBanner> createState() => _LivingFoundryBannerState();
}

class _LivingFoundryBannerState extends State<LivingFoundryBanner>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _bellowsController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
      value: 0.35,
    );
    _bellowsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 780),
    );
    _syncTier();
    GraphicsQualityService.instance.addListener(_onGraphicsChanged);
  }

  void _onGraphicsChanged() {
    if (!mounted) return;
    _syncTier();
    setState(() {});
  }

  void _syncTier() {
    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    if (gfx.isLow) {
      if (_ambientController.isAnimating) {
        _ambientController.stop();
        _ambientController.value = 0.35;
      }
    } else if (!_ambientController.isAnimating) {
      _ambientController.repeat();
    }
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_onGraphicsChanged);
    _ambientController.dispose();
    _bellowsController.dispose();
    super.dispose();
  }

  void _triggerBellows() {
    _bellowsController.forward(from: 0.0);
    unawaited(GameSfxService.instance.play(GameSfx.anvilStrike));
    unawaited(AppHaptics.anvilStrikePulse());
  }

  @override
  Widget build(BuildContext context) {
    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final ImageProvider<Object> furnaceImg = ResizeImage.resizeIfNeeded(
      gfx.isLow ? 480 : 960,
      null,
      const AssetImage('assets/v15/master_foundry_furnace_bg.jpg'),
    );
    final double height = widget.compact ? 114.0 : 132.0;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (widget.isProducing
                  ? const Color(0xFFFB923C)
                  : const Color(0xFFFBBF24))
              .withValues(alpha: 0.72),
          width: 1.25,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0xA6000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image(
            image: furnaceImg,
            fit: BoxFit.cover,
            alignment: const Alignment(0, -0.1),
            filterQuality: gfx.filterQuality,
            errorBuilder: (_, _, _) =>
                const ColoredBox(color: Color(0xFF1A0B05)),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[
                  Color(0xEB090C15),
                  Color(0x8A090C15),
                  Color(0xB8090C15),
                ],
              ),
            ),
          ),
          RepaintBoundary(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[
                  _ambientController,
                  _bellowsController,
                ]),
                builder: (BuildContext context, _) {
                  return CustomPaint(
                    painter: _LivingFoundryMoltenPainter(
                      phase: _ambientController.value,
                      bellowsBoost: _bellowsController.value,
                      isProducing: widget.isProducing,
                      emberCount: gfx.isLow
                          ? 5
                          : (gfx.tier.index >= GraphicsQualityTier.high.index
                              ? 18
                              : 11),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xDE1F1006),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFFB923C)
                                .withValues(alpha: 0.78),
                          ),
                        ),
                        child: Text(
                          widget.statusBadge,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFEF08A),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  key: const Key('living_foundry_bellows_btn'),
                  onTap: _triggerBellows,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFFEA580C), Color(0xFF9A3412)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFEF08A).withValues(alpha: 0.85),
                      ),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x66F97316),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 18,
                          color: Color(0xFFFEF9C3),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Körükle',
                          style: TextStyle(
                            color: Color(0xFFFEF9C3),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LivingFoundryMoltenPainter extends CustomPainter {
  const _LivingFoundryMoltenPainter({
    required this.phase,
    required this.bellowsBoost,
    required this.isProducing,
    required this.emberCount,
  });

  final double phase;
  final double bellowsBoost;
  final bool isProducing;
  final int emberCount;

  @override
  void paint(Canvas canvas, Size size) {
    final double boost = bellowsBoost > 0.0
        ? math.sin(bellowsBoost * math.pi).clamp(0.0, 1.0)
        : 0.0;
    final double pulse = 0.5 + 0.5 * math.sin(phase * math.pi * 2);
    final double heatAlpha =
        ((isProducing ? 0.34 : 0.20) + pulse * 0.12 + boost * 0.38)
            .clamp(0.0, 0.88);

    // 1. Furnace hearth glow on right side
    final Offset hearth = Offset(size.width * 0.72, size.height * 0.52);
    canvas.drawCircle(
      hearth,
      size.height * (0.72 + boost * 0.25),
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            const Color(0xFFFEF08A).withValues(alpha: heatAlpha * 0.75),
            const Color(0xFFF97316).withValues(alpha: heatAlpha * 0.52),
            Colors.transparent,
          ],
          stops: const <double>[0.0, 0.48, 1.0],
        ).createShader(
          Rect.fromCircle(center: hearth, radius: size.height * 0.95),
        ),
    );

    // 2. Molten gold channel ribbon along bottom-right trough
    final Path molten = Path()
      ..moveTo(size.width * 0.42, size.height * 0.92)
      ..quadraticBezierTo(
        size.width * 0.64,
        size.height * (0.76 - 0.04 * math.sin(phase * math.pi * 2)),
        size.width * 0.96,
        size.height * 0.86,
      );
    canvas.drawPath(
      molten,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 + boost * 2.5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFBBF24).withValues(alpha: heatAlpha * 0.85),
    );

    // 3. Rising forge embers
    final Paint emberPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < emberCount; i++) {
      final double seed = (i * 0.173) % 1.0;
      final double t = (phase * (1.0 + (i % 3) * 0.35) + seed) % 1.0;
      final double x = size.width * (0.45 + ((i * 37) % 52) / 100.0) +
          math.sin((t + seed) * math.pi * 4) * 8.0;
      final double y = size.height * (1.0 - t * 0.95);
      final double r = (1.3 + (i % 3) * 0.75) * (1.0 + boost * 0.65);
      final double a = ((1.0 - t) * (0.55 + boost * 0.40)).clamp(0.0, 1.0);
      emberPaint.color = (i.isEven
              ? const Color(0xFFFEF08A)
              : const Color(0xFFF97316))
          .withValues(alpha: a);
      canvas.drawCircle(Offset(x, y), r, emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LivingFoundryMoltenPainter oldDelegate) {
    return (oldDelegate.phase - phase).abs() > 0.006 ||
        (oldDelegate.bellowsBoost - bellowsBoost).abs() > 0.006 ||
        oldDelegate.isProducing != isProducing ||
        oldDelegate.emberCount != emberCount;
  }
}
