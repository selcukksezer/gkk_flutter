import 'package:flutter/material.dart';

enum CharacterSlotStatus {
  active,
  empty,
  locked,
}

class CharacterSlotInfo {
  const CharacterSlotInfo({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.status,
    this.characterClassId,
  });

  final int index;
  final String title;
  final String subtitle;
  final CharacterSlotStatus status;
  final String? characterClassId;
}

class CharacterSlotSelector extends StatelessWidget {
  const CharacterSlotSelector({
    super.key,
    required this.selectedSlotIndex,
    required this.onSlotSelected,
    this.accentColor = const Color(0xFFFFB300),
  });

  final int selectedSlotIndex;
  final ValueChanged<int> onSlotSelected;
  final Color accentColor;

  static const List<CharacterSlotInfo> defaultSlots = <CharacterSlotInfo>[
    CharacterSlotInfo(
      index: 0,
      title: 'Yuva I',
      subtitle: 'Aktif // Yeni',
      status: CharacterSlotStatus.active,
    ),
    CharacterSlotInfo(
      index: 1,
      title: 'Yuva II',
      subtitle: 'Açık // Boş',
      status: CharacterSlotStatus.empty,
    ),
    CharacterSlotInfo(
      index: 2,
      title: 'Yuva III',
      subtitle: 'VIP // Kilitli',
      status: CharacterSlotStatus.locked,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE60D0F14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black45,
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: defaultSlots.map((CharacterSlotInfo slot) {
          final bool isSelected = selectedSlotIndex == slot.index;
          return Expanded(
            child: _SlotItem(
              slot: slot,
              isSelected: isSelected,
              accentColor: accentColor,
              onTap: () {
                if (slot.status == CharacterSlotStatus.locked) {
                  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                    SnackBar(
                      duration: const Duration(milliseconds: 1800),
                      backgroundColor: const Color(0xFF1E222B),
                      content: Row(
                        children: const <Widget>[
                          Icon(Icons.lock_outline_rounded, color: Colors.amberAccent, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Yuva III Seviye 50 veya VIP üyelik gerektirir.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  onSlotSelected(slot.index);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SlotItem extends StatelessWidget {
  const _SlotItem({
    required this.slot,
    required this.isSelected,
    required this.accentColor,
    required this.onTap,
  });

  final CharacterSlotInfo slot;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isLocked = slot.status == CharacterSlotStatus.locked;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isSelected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      accentColor.withValues(alpha: 0.22),
                      const Color(0xFF181B22),
                    ],
                  )
                : LinearGradient(
                    colors: <Color>[
                      Colors.white.withValues(alpha: isLocked ? 0.02 : 0.04),
                      Colors.transparent,
                    ],
                  ),
            border: Border.all(
              color: isSelected
                  ? accentColor.withValues(alpha: 0.8)
                  : Colors.white.withValues(alpha: isLocked ? 0.04 : 0.10),
              width: isSelected ? 1.4 : 1,
            ),
            boxShadow: isSelected
                ? <BoxShadow>[
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.22),
                      blurRadius: 10,
                      spreadRadius: -1,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    isLocked
                        ? Icons.lock_outline_rounded
                        : (isSelected
                            ? Icons.star_rounded
                            : Icons.person_outline_rounded),
                    size: 13,
                    color: isSelected
                        ? accentColor
                        : (isLocked ? Colors.white30 : Colors.white60),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    slot.title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : (isLocked ? Colors.white38 : Colors.white70),
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                slot.subtitle,
                style: TextStyle(
                  color: isSelected
                      ? accentColor
                      : (isLocked ? Colors.white24 : Colors.white38),
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
