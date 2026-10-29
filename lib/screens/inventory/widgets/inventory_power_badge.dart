import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/power_helpers.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../theme/app_text_styles.dart';
import 'aion_rarity_glow.dart';

/// 2027 Aion 2 Dark Fantasy Combat Score Rating Badge.
/// Displays live animated combat power with metallic gradient border,
/// specular sweep shimmer, dynamic tier crest, and floating delta indicators.
class InventoryPowerBadge extends ConsumerStatefulWidget {
  const InventoryPowerBadge({super.key});

  @override
  ConsumerState<InventoryPowerBadge> createState() =>
      _InventoryPowerBadgeState();
}

class _InventoryPowerBadgeState extends ConsumerState<InventoryPowerBadge>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _countCtrl;

  int? _lastPower;
  int _startPower = 0;
  int _targetPower = 0;
  int _currentAnimatedPower = 0;
  bool? _lastWasIncrease;
  int _lastDelta = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _countCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addListener(() {
        final double progress = Curves.easeOutCubic.transform(_countCtrl.value);
        setState(() {
          _currentAnimatedPower =
              (_startPower + ((_targetPower - _startPower) * progress)).round();
        });
      });

    ref.listenManual(inventoryProvider, (previous, next) => _syncPower());
    ref.listenManual(playerProvider, (previous, next) => _syncPower());
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPower());
  }

  int _readPower() => readPlayerTotalPower(ref);

  void _syncPower() {
    if (!mounted) return;
    final int next = _readPower();
    final int? prev = _lastPower;

    if (prev == null) {
      _lastPower = next;
      _startPower = next;
      _targetPower = next;
      setState(() => _currentAnimatedPower = next);
      return;
    }

    if (prev == next) {
      if (_targetPower != next) {
        setState(() {
          _targetPower = next;
          _currentAnimatedPower = next;
        });
      }
      return;
    }

    final bool isIncrease = next > prev;
    _lastWasIncrease = isIncrease;
    _lastDelta = (next - prev).abs();
    _lastPower = next;

    _startPower = _currentAnimatedPower;
    _targetPower = next;
    _countCtrl.forward(from: 0);
    _pulseCtrl.forward(from: 0);

    if (isIncrease) {
      AionHaptics.equipSuccess();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(inventoryProvider);
    ref.watch(playerProvider);

    final int displayValue = _currentAnimatedPower > 0 || _lastPower != null
        ? _currentAnimatedPower
        : _readPower();

    final Color pulseColor = _lastWasIncrease == true
        ? const Color(0xFF07CA6B)
        : _lastWasIncrease == false
            ? const Color(0xFFEF4444)
            : const Color(0xFFFFB800);

    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_pulseCtrl, _shimmerCtrl]),
      builder: (BuildContext context, Widget? child) {
        final double pulseT = Curves.easeOut.transform(_pulseCtrl.value);
        final double scale = 1.0 + (pulseT * 0.05);
        final double glowAlpha = (1.0 - pulseT) * 0.40;

        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                if (glowAlpha > 0)
                  BoxShadow(
                    color: pulseColor.withValues(alpha: glowAlpha),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _PowerBadgeMetallicShell(
                  value: formatPowerValue(displayValue),
                  shimmerProgress: _shimmerCtrl.value,
                  powerLevel: displayValue,
                ),
                if (_pulseCtrl.isAnimating && _lastWasIncrease != null) ...<Widget>[
                  const SizedBox(width: 6),
                  _FloatingDeltaChip(
                    increase: _lastWasIncrease!,
                    delta: _lastDelta,
                    opacity: (1.0 - pulseT).clamp(0.0, 1.0),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PowerBadgeMetallicShell extends StatelessWidget {
  const _PowerBadgeMetallicShell({
    required this.value,
    required this.shimmerProgress,
    required this.powerLevel,
  });

  final String value;
  final double shimmerProgress;
  final int powerLevel;

  (String, Color, IconData) _getCombatTier(int power) {
    if (power >= 20000) {
      return ('İLAHİ', const Color(0xFFFFB800), Icons.workspace_premium_rounded);
    } else if (power >= 10000) {
      return ('ARKON', const Color(0xFF06D0D8), Icons.military_tech_rounded);
    } else if (power >= 5000) {
      return ('KAHRAMAN', const Color(0xFFA855F7), Icons.shield_rounded);
    } else if (power >= 1000) {
      return ('SAVAŞÇI', const Color(0xFF38BDF8), Icons.hardware_rounded);
    }
    return ('ÇAYLAK', const Color(0xFF94A3B8), Icons.radio_button_checked_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final (tierTitle, tierColor, tierIcon) = _getCombatTier(powerLevel);

    return Container(
      constraints: const BoxConstraints(minWidth: 84, maxWidth: 140),
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            tierColor.withValues(alpha: 0.95),
            const Color(0xFF1E293B),
            tierColor.withValues(alpha: 0.70),
          ],
          stops: <double>[
            0.0,
            (shimmerProgress).clamp(0.1, 0.9),
            1.0,
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tierColor.withValues(alpha: 0.28),
            blurRadius: 10,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.8),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xF5111827),
              Color(0xFA090E17),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  tierIcon,
                  size: 9.5,
                  color: tierColor,
                ),
                const SizedBox(width: 3),
                Text(
                  'GÜÇ · $tierTitle',
                  style: AppTextStyles.micro.copyWith(
                    fontSize: 8.0,
                    color: tierColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h3.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
                height: 1.0,
                color: Colors.white,
                shadows: <Shadow>[
                  Shadow(
                    color: tierColor.withValues(alpha: 0.75),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingDeltaChip extends StatelessWidget {
  const _FloatingDeltaChip({
    required this.increase,
    required this.delta,
    required this.opacity,
  });

  final bool increase;
  final int delta;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();

    final Color color =
        increase ? const Color(0xFF07CA6B) : const Color(0xFFEF4444);

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.60)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 6,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              increase
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 11,
              color: color,
            ),
            const SizedBox(width: 2),
            Text(
              '${increase ? '+' : '-'}$delta',
              style: AppTextStyles.micro.copyWith(
                color: color,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
