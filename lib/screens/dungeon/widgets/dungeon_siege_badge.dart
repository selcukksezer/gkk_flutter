import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'dungeon_siege_design.dart';

class DungeonSiegeBadge extends StatelessWidget {
  const DungeonSiegeBadge({
    super.key,
    required this.siegeActive,
    required this.slotCount,
    required this.occupiedSlots,
    required this.hasMySlot,
    this.onTap,
    this.compact = false,
  });

  final bool siegeActive;
  final int slotCount;
  final int occupiedSlots;
  final bool hasMySlot;
  final VoidCallback? onTap;
  final bool compact;

  String get _label {
    if (!siegeActive) return 'KUŞATMA';
    if (hasMySlot) return 'KUŞATMA ★';
    return 'KUŞATMA $occupiedSlots/$slotCount';
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = hasMySlot
        ? SiegePalette.gold
        : siegeActive
            ? SiegePalette.fuchsia
            : SiegePalette.titanium;

    final Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 6 : 8),
        gradient: LinearGradient(
          colors: <Color>[
            accent.withValues(alpha: siegeActive ? 0.22 : 0.08),
            AppColors.spaceNavy.withValues(alpha: 0.9),
          ],
        ),
        border: Border.all(color: accent.withValues(alpha: siegeActive ? 0.55 : 0.25)),
        boxShadow: siegeActive
            ? <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.2), blurRadius: 10)]
            : null,
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w900,
          color: accent,
          letterSpacing: 0.7,
        ),
      ),
    );

    if (onTap == null) return badge;

    return SiegePressable(
      onTap: onTap,
      child: badge,
    );
  }
}
