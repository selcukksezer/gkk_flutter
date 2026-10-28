import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/services/app_haptics.dart';
import '../../core/services/game_sfx_service.dart';
import '../../core/services/graphics_quality_service.dart';

enum RewardMagnetKind {
  gold,
  gem,
  forgeItem,
}

/// V15 Pack 5 (shared across Mekan Pit, Moradon World Boss, Crafting & Facilities):
/// Bezier-curved `Coin-to-Wallet` Magnet Particle Burst!
///
/// Can be launched imperatively via [RewardMagnetOverlay.burstToTopWallet] on any
/// [BuildContext]'s root [Overlay], or embedded declaratively via [RewardMagnetBurstWidget].
class RewardMagnetOverlay {
  RewardMagnetOverlay._();

  static int _debugBurstCount = 0;

  @visibleForTesting
  static int get debugBurstCount => _debugBurstCount;

  @visibleForTesting
  static void resetForTesting() {
    _debugBurstCount = 0;
  }

  /// Launches flying reward coins/gems from [origin] (defaults to screen center)
  /// along curved Bezier arcs directly into the top HUD resource wallet bar!
  static void burstToTopWallet(
    BuildContext context, {
    Offset? origin,
    RewardMagnetKind kind = RewardMagnetKind.gold,
    String? label,
  }) {
    _debugBurstCount += 1;
    unawaited(GameSfxService.instance.play(GameSfx.coinMagnet));
    unawaited(AppHaptics.coinCascade(ticks: 3));

    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final Size screen = MediaQuery.sizeOf(context);
    final Offset start = origin ?? Offset(screen.width * 0.5, screen.height * 0.56);
    final Offset target = switch (kind) {
      RewardMagnetKind.gem => Offset(screen.width * 0.78, 54.0),
      RewardMagnetKind.forgeItem => Offset(screen.width * 0.32, screen.height - 52.0),
      RewardMagnetKind.gold => Offset(screen.width * 0.70, 44.0),
    };

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext ctx) {
        return IgnorePointer(
          child: RewardMagnetBurstWidget(
            origin: start,
            target: target,
            kind: kind,
            label: label,
            onCompleted: () {
              if (entry.mounted) {
                entry.remove();
              }
            },
          ),
        );
      },
    );
    overlay.insert(entry);
  }
}

class RewardMagnetBurstWidget extends StatefulWidget {
  const RewardMagnetBurstWidget({
    super.key = const Key('reward_magnet_burst_widget'),
    required this.origin,
    required this.target,
    this.kind = RewardMagnetKind.gold,
    this.label,
    this.onCompleted,
  });

  final Offset origin;
  final Offset target;
  final RewardMagnetKind kind;
  final String? label;
  final VoidCallback? onCompleted;

  @override
  State<RewardMagnetBurstWidget> createState() =>
      _RewardMagnetBurstWidgetState();
}

class _RewardMagnetBurstWidgetState extends State<RewardMagnetBurstWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 920),
    )..addStatusListener((AnimationStatus st) {
        if (st == AnimationStatus.completed) {
          widget.onCompleted?.call();
        }
      });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLow = GraphicsQualityService.instance.profile.isLow;
    final int particleCount = isLow ? 6 : 14;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (BuildContext context, _) {
        final double t = _ctrl.value;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CustomPaint(
              key: const ValueKey<String>('reward_magnet_particles_paint'),
              painter: _RewardMagnetPainter(
                progress: t,
                origin: widget.origin,
                target: widget.target,
                kind: widget.kind,
                particleCount: particleCount,
                isLowTier: isLow,
              ),
            ),
            if (widget.label != null && t < 0.78)
              Positioned(
                left: (widget.origin.dx - 90).clamp(12.0, 260.0),
                top: (widget.origin.dy - 28 - t * 48).clamp(48.0, 720.0),
                child: Opacity(
                  opacity: (1.0 - t / 0.78).clamp(0.0, 1.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xDD0B1120),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: const Color(0xFFFBBF24).withValues(alpha: 0.85),
                      ),
                    ),
                    child: Text(
                      widget.label!,
                      style: const TextStyle(
                        color: Color(0xFFFEF08A),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _RewardMagnetPainter extends CustomPainter {
  const _RewardMagnetPainter({
    required this.progress,
    required this.origin,
    required this.target,
    required this.kind,
    required this.particleCount,
    required this.isLowTier,
  });

  final double progress;
  final Offset origin;
  final Offset target;
  final RewardMagnetKind kind;
  final int particleCount;
  final bool isLowTier;

  @override
  void paint(Canvas canvas, Size size) {
    final Color primary = switch (kind) {
      RewardMagnetKind.gem => const Color(0xFF38BDF8),
      RewardMagnetKind.forgeItem => const Color(0xFFC084FC),
      RewardMagnetKind.gold => const Color(0xFFFBBF24),
    };
    final Color core = switch (kind) {
      RewardMagnetKind.gem => const Color(0xFFE0F2FE),
      RewardMagnetKind.forgeItem => const Color(0xFFF3E8FF),
      RewardMagnetKind.gold => const Color(0xFFFEF08A),
    };

    for (int i = 0; i < particleCount; i++) {
      final double delay = (i / particleCount) * 0.34;
      final double localT = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0);
      if (localT <= 0.0 || localT >= 1.0) continue;

      final double eased = Curves.easeInOutCubic.transform(localT);
      final double spreadAng = (i * 2.39996) % (math.pi * 2);
      final double spreadRadius = 38.0 + (i % 4) * 22.0;
      final Offset ctrl = Offset(
        origin.dx + math.cos(spreadAng) * spreadRadius * 1.6,
        math.min(origin.dy, target.dy) + math.sin(spreadAng) * spreadRadius - 32.0,
      );

      final double u = 1.0 - eased;
      final Offset pos = Offset(
        u * u * origin.dx + 2 * u * eased * ctrl.dx + eased * eased * target.dx,
        u * u * origin.dy + 2 * u * eased * ctrl.dy + eased * eased * target.dy,
      );

      if (!isLowTier) {
        canvas.drawCircle(
          pos,
          10.5 * (1.0 - localT * 0.35),
          Paint()
            ..blendMode = BlendMode.plus
            ..color = primary.withValues(alpha: 0.38),
        );
      }

      canvas.drawCircle(
        pos,
        5.5 * (1.0 - localT * 0.25),
        Paint()..color = primary,
      );
      canvas.drawCircle(
        pos.translate(-1.2, -1.2),
        2.3,
        Paint()..color = core,
      );
    }

    if (progress > 0.68) {
      final double ringT = ((progress - 0.68) / 0.32).clamp(0.0, 1.0);
      canvas.drawCircle(
        target,
        10.0 + ringT * 26.0,
        Paint()
          ..blendMode = BlendMode.plus
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * (1.0 - ringT)
          ..color = core.withValues(alpha: (1.0 - ringT) * 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RewardMagnetPainter oldDelegate) {
    return (oldDelegate.progress - progress).abs() > 0.005;
  }
}
