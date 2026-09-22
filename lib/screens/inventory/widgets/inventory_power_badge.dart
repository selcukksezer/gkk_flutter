import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/power_helpers.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Envanter ustunde canli POWER sayaci — kuşanma/çıkarmada animasyonlu guncellenir.
class InventoryPowerBadge extends ConsumerStatefulWidget {
  const InventoryPowerBadge({super.key});

  @override
  ConsumerState<InventoryPowerBadge> createState() =>
      _InventoryPowerBadgeState();
}

class _InventoryPowerBadgeState extends ConsumerState<InventoryPowerBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  int? _lastPower;
  int _displayPower = 0;
  bool? _lastWasIncrease;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    ref.listenManual(inventoryProvider, (_, __) => _syncPower());
    ref.listenManual(playerProvider, (_, __) => _syncPower());
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncPower());
  }

  int _readPower() => readPlayerTotalPower(ref);

  void _syncPower() {
    if (!mounted) return;
    final int next = _readPower();
    final int? prev = _lastPower;
    if (prev == null) {
      _lastPower = next;
      setState(() => _displayPower = next);
      return;
    }
    if (prev == next) {
      if (_displayPower != next) {
        setState(() => _displayPower = next);
      }
      return;
    }
    _lastWasIncrease = next > prev;
    _lastPower = next;
    setState(() => _displayPower = next);
    _pulseCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(inventoryProvider);
    ref.watch(playerProvider);

    final int power = _displayPower > 0 || _lastPower != null
        ? _displayPower
        : _readPower();
    final Color pulseColor = _lastWasIncrease == true
        ? AppColors.toxicNeon
        : _lastWasIncrease == false
            ? AppColors.coralFlare
            : AppColors.cyberFuchsia;

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeOut.transform(_pulseCtrl.value);
        final double scale = 1 + (t * 0.08);
        final double glow = (1 - t) * 0.35;

        return Transform.scale(
          scale: scale,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: <BoxShadow>[
                if (glow > 0)
                  BoxShadow(
                    color: pulseColor.withValues(alpha: glow),
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _PowerBadgeShell(value: formatPowerValue(power)),
                if (_pulseCtrl.isAnimating && _lastWasIncrease != null) ...<Widget>[
                  const SizedBox(width: 8),
                  _DeltaChip(
                    increase: _lastWasIncrease!,
                    opacity: (1 - t).clamp(0.0, 1.0),
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

class _PowerBadgeShell extends StatelessWidget {
  const _PowerBadgeShell({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72, maxWidth: 120),
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.cyberFuchsia.withValues(alpha: 0.95),
            AppColors.mysticRuby.withValues(alpha: 0.65),
          ],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.cyberFuchsia.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10.6),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.spaceNavy.withValues(alpha: 0.96),
              AppColors.carbonVoid.withValues(alpha: 0.98),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              'POWER',
              style: AppTextStyles.micro.copyWith(
                fontSize: 8.5,
                color: AppColors.textPrimary.withValues(alpha: 0.88),
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.h3.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1,
                shadows: <Shadow>[
                  Shadow(
                    color: AppColors.cyberFuchsia.withValues(alpha: 0.7),
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

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({
    required this.increase,
    required this.opacity,
  });

  final bool increase;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity <= 0) return const SizedBox.shrink();

    final Color color =
        increase ? AppColors.toxicNeon : AppColors.coralFlare;

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              increase
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 12,
              color: color,
            ),
            const SizedBox(width: 2),
            Text(
              increase ? 'ARTTI' : 'AZALDI',
              style: AppTextStyles.micro.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
