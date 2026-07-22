import 'package:flutter/material.dart';

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
    final Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 7,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(compact ? 4 : 6),
        color: siegeActive
            ? const Color(0xFFEF4444).withValues(alpha: 0.18)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(
          color: siegeActive
              ? const Color(0xFFEF4444).withValues(alpha: 0.55)
              : Colors.white24,
        ),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: compact ? 9 : 10,
          fontWeight: FontWeight.w800,
          color: siegeActive ? const Color(0xFFFCA5A5) : Colors.white54,
          letterSpacing: 0.6,
        ),
      ),
    );

    if (onTap == null) return badge;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: badge,
    );
  }
}
