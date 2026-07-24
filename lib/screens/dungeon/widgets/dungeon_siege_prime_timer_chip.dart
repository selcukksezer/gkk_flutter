import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/dungeon_siege_model.dart';
import '../../../models/dungeon_siege_prime_timer.dart';
import 'dungeon_siege_badge.dart';
import 'dungeon_siege_design.dart';

/// Kuşatma badge yanında prime geri sayım.
class DungeonSiegePrimeTimerChip extends StatefulWidget {
  const DungeonSiegePrimeTimerChip({
    super.key,
    required this.config,
    this.compact = true,
  });

  final DungeonSiegeConfig config;
  final bool compact;

  @override
  State<DungeonSiegePrimeTimerChip> createState() => _DungeonSiegePrimeTimerChipState();
}

class _DungeonSiegePrimeTimerChipState extends State<DungeonSiegePrimeTimerChip> {
  Timer? _timer;
  DungeonSiegePrimeTimerSnapshot _snapshot = const DungeonSiegePrimeTimerSnapshot(
    mode: DungeonSiegePrimeTimerMode.hidden,
  );

  @override
  void initState() {
    super.initState();
    _refreshSnapshot();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refreshSnapshot());
  }

  @override
  void didUpdateWidget(covariant DungeonSiegePrimeTimerChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.isEnabled != widget.config.isEnabled ||
        oldWidget.config.timezone != widget.config.timezone ||
        oldWidget.config.primeWindows != widget.config.primeWindows) {
      _refreshSnapshot();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _refreshSnapshot() {
    final DungeonSiegePrimeTimerSnapshot next = DungeonSiegePrimeSchedule.snapshot(
      windows: widget.config.primeWindows,
      timezone: widget.config.timezone,
      isEnabled: widget.config.isEnabled,
    );
    if (next.mode != _snapshot.mode ||
        next.formattedRemaining != _snapshot.formattedRemaining) {
      if (mounted) setState(() => _snapshot = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_snapshot.isVisible) return const SizedBox.shrink();

    final bool untilEnd = _snapshot.mode == DungeonSiegePrimeTimerMode.untilEnd;
    final Color accent = untilEnd ? SiegePalette.neon : SiegePalette.gold;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 5 : 7,
        vertical: widget.compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.compact ? 6 : 8),
        color: accent.withValues(alpha: 0.1),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.schedule_rounded, size: widget.compact ? 9 : 10, color: accent),
          const SizedBox(width: 3),
          Text(
            '${_snapshot.labelPrefix} ${_snapshot.formattedRemaining}',
            style: TextStyle(
              fontSize: widget.compact ? 8.5 : 9.5,
              fontWeight: FontWeight.w800,
              color: accent,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge + prime timer satırı.
class DungeonSiegeBadgeWithTimer extends StatelessWidget {
  const DungeonSiegeBadgeWithTimer({
    super.key,
    required this.siegeActive,
    required this.slotCount,
    required this.occupiedSlots,
    required this.hasMySlot,
    required this.config,
    this.onTap,
    this.compact = false,
    this.showTimer = true,
  });

  final bool siegeActive;
  final int slotCount;
  final int occupiedSlots;
  final bool hasMySlot;
  final DungeonSiegeConfig config;
  final VoidCallback? onTap;
  final bool compact;
  final bool showTimer;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        DungeonSiegeBadge(
          siegeActive: siegeActive,
          slotCount: slotCount,
          occupiedSlots: occupiedSlots,
          hasMySlot: hasMySlot,
          onTap: onTap,
          compact: compact,
        ),
        if (showTimer && config.isEnabled) ...<Widget>[
          const SizedBox(width: 4),
          DungeonSiegePrimeTimerChip(config: config, compact: compact),
        ],
      ],
    );
  }
}
