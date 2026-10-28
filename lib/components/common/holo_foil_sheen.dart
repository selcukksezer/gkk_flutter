import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/app_foreground_service.dart';
import '../../core/services/graphics_quality_service.dart';
import '../../models/item_model.dart';

/// Shared single-timer phase clock for all mounted [HoloFoilRarityBox] cards.
///
/// Avoids creating per-card [AnimationController]s when dozens of inventory or
/// market cards are visible simultaneously, and stays completely asleep (`0 Hz`)
/// on `Low` graphics tier, when backgrounded, or when no foil cards are mounted.
class _SharedHoloFoilClock extends ChangeNotifier {
  _SharedHoloFoilClock._();

  static final _SharedHoloFoilClock instance = _SharedHoloFoilClock._();

  Timer? _timer;
  int _activeSubscribers = 0;
  double _phase = 0.28;

  double get phase => _phase;

  static bool get _isTestBinding {
    try {
      final String name = WidgetsBinding.instance.runtimeType.toString();
      return name.contains('Test');
    } catch (_) {
      return false;
    }
  }

  void subscribe() {
    _activeSubscribers++;
    syncState();
  }

  void unsubscribe() {
    _activeSubscribers = math.max(0, _activeSubscribers - 1);
    syncState();
  }

  void syncState() {
    final bool shouldAnimate = _activeSubscribers > 0 &&
        GraphicsQualityService.instance.profile.enableHoloFoilSweep &&
        AppForegroundService.instance.isForeground &&
        (!_isTestBinding || HoloFoilRarityBox.debugAnimateInTests);

    if (!shouldAnimate) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(const Duration(milliseconds: 45), (_) {
      if (!AppForegroundService.instance.isForeground ||
          !GraphicsQualityService.instance.profile.enableHoloFoilSweep) {
        syncState();
        return;
      }
      _phase = (_phase + 0.016) % 1.0;
      notifyListeners();
    });
  }
}

/// Prismatic holographic foil sheen wrapper for `epic` / `legendary` / `mythic`
/// or `+7..+10` enhanced gear slots.
///
/// - Below `epic` and `< +7`: zero-cost passthrough (`return child`).
/// - `Low` tier: crisp static metallic corner sheen (`0 Hz` CPU/GPU cost).
/// - `Medium` / `High` / `Ultra`: animated diagonal holographic foil band + corner glint.
class HoloFoilRarityBox extends StatefulWidget {
  const HoloFoilRarityBox({
    super.key,
    required this.rarity,
    required this.child,
    this.enhancementLevel = 0,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
    this.forceFoil = false,
  });

  final Rarity rarity;
  final int enhancementLevel;
  final BorderRadius borderRadius;
  final bool forceFoil;
  final Widget child;

  /// Allows unit tests to explicitly verify animated sweep ticks without hanging
  /// existing `pumpAndSettle()` suites.
  @visibleForTesting
  static bool debugAnimateInTests = false;

  static bool qualifies({
    required Rarity rarity,
    required int enhancementLevel,
    bool forceFoil = false,
  }) {
    return forceFoil ||
        rarity.index >= Rarity.epic.index ||
        enhancementLevel >= 7;
  }

  @override
  State<HoloFoilRarityBox> createState() => _HoloFoilRarityBoxState();
}

class _HoloFoilRarityBoxState extends State<HoloFoilRarityBox> {
  bool _subscribed = false;

  bool get _qualifies => HoloFoilRarityBox.qualifies(
        rarity: widget.rarity,
        enhancementLevel: widget.enhancementLevel,
        forceFoil: widget.forceFoil,
      );

  @override
  void initState() {
    super.initState();
    GraphicsQualityService.instance.addListener(_onGfxChanged);
    _updateSubscription();
  }

  @override
  void didUpdateWidget(covariant HoloFoilRarityBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateSubscription();
  }

  void _onGfxChanged() {
    _updateSubscription();
    if (mounted && _qualifies) {
      setState(() {});
    }
  }

  void _updateSubscription() {
    final bool wantSub = _qualifies &&
        GraphicsQualityService.instance.profile.enableHoloFoilSweep;
    if (wantSub && !_subscribed) {
      _subscribed = true;
      _SharedHoloFoilClock.instance.subscribe();
    } else if (!wantSub && _subscribed) {
      _subscribed = false;
      _SharedHoloFoilClock.instance.unsubscribe();
    }
  }

  @override
  void dispose() {
    GraphicsQualityService.instance.removeListener(_onGfxChanged);
    if (_subscribed) {
      _subscribed = false;
      _SharedHoloFoilClock.instance.unsubscribe();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_qualifies) return widget.child;

    final GraphicsProfile gfx = GraphicsQualityService.instance.profile;
    final Color baseAccent = _resolveFoilAccent(
      widget.rarity,
      widget.enhancementLevel,
    );

    if (!gfx.enableHoloFoilSweep) {
      // Low tier: static crisp metallic corner glint (0 Hz ticker cost)
      return Stack(
        fit: StackFit.passthrough,
        children: <Widget>[
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: CustomPaint(
                  key: const ValueKey<String>('holo_foil_static_paint'),
                  painter: _HoloFoilSheenPainter(
                    phase: 0.34,
                    accent: baseAccent,
                    enhancementLevel: widget.enhancementLevel,
                    isLowTier: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: AnimatedBuilder(
                animation: _SharedHoloFoilClock.instance,
                builder: (BuildContext context, _) {
                  // Offset phase slightly by hash so adjacent slots shimmer organically!
                  final double offset =
                      ((widget.rarity.index * 17 + widget.enhancementLevel * 31) %
                              100) /
                          100.0;
                  final double phase =
                      (_SharedHoloFoilClock.instance.phase + offset) % 1.0;
                  return CustomPaint(
                    key: const ValueKey<String>('holo_foil_sweep_paint'),
                    painter: _HoloFoilSheenPainter(
                      phase: phase,
                      accent: baseAccent,
                      enhancementLevel: widget.enhancementLevel,
                      isLowTier: false,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Color _resolveFoilAccent(Rarity rarity, int enhancement) {
    if (enhancement >= 10) return const Color(0xFFFF3860);
    if (enhancement >= 9) return const Color(0xFFFF9824);
    if (enhancement >= 8) return const Color(0xFF4AE8FF);
    return switch (rarity) {
      Rarity.mythic => const Color(0xFFFF3B4E),
      Rarity.legendary => const Color(0xFFFF9F1C),
      Rarity.epic => const Color(0xFFC06CFF),
      Rarity.rare => const Color(0xFF4DA3FF),
      _ => const Color(0xFF8BE9FD),
    };
  }
}

class _HoloFoilSheenPainter extends CustomPainter {
  const _HoloFoilSheenPainter({
    required this.phase,
    required this.accent,
    required this.enhancementLevel,
    required this.isLowTier,
  });

  final double phase;
  final Color accent;
  final int enhancementLevel;
  final bool isLowTier;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Rect rect = Offset.zero & size;

    if (isLowTier) {
      final Paint staticBand = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const <double>[0.0, 0.28, 0.44, 1.0],
          colors: <Color>[
            accent.withValues(alpha: 0.20),
            Colors.white.withValues(alpha: 0.14),
            Colors.transparent,
            accent.withValues(alpha: 0.08),
          ],
        ).createShader(rect);
      canvas.drawRect(rect, staticBand);
      return;
    }

    // Sweeping holographic prismatic band (-0.6 -> +1.6 across card diagonal)
    final double sweepCenter = -0.45 + phase * 1.90;
    final Color prismB = HSLColor.fromColor(accent)
        .withHue((HSLColor.fromColor(accent).hue + 52.0) % 360.0)
        .withLightness(0.68)
        .toColor();

    final Paint foilPaint = Paint()
      ..blendMode = BlendMode.plus
      ..shader = LinearGradient(
        begin: Alignment(-1.2 + sweepCenter * 1.5, -1.0),
        end: Alignment(-0.2 + sweepCenter * 1.5, 1.0),
        stops: const <double>[0.0, 0.34, 0.50, 0.66, 1.0],
        colors: <Color>[
          Colors.transparent,
          accent.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: enhancementLevel >= 9 ? 0.30 : 0.22),
          prismB.withValues(alpha: 0.16),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, foilPaint);

    // Subtle luminous inner edge highlight for +8..+10 / Mythic-Legendary
    final Paint rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = enhancementLevel >= 9 ? 1.35 : 1.0
      ..color = accent.withValues(
        alpha: 0.24 + 0.14 * math.sin(phase * math.pi * 2),
      );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.6), const Radius.circular(9)),
      rimPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HoloFoilSheenPainter oldDelegate) {
    return (oldDelegate.phase - phase).abs() > 0.004 ||
        oldDelegate.accent != accent ||
        oldDelegate.isLowTier != isLowTier ||
        oldDelegate.enhancementLevel != enhancementLevel;
  }
}
