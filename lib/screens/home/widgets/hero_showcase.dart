import 'package:flutter/material.dart';
import '../../../../core/services/app_foreground_service.dart';
import '../../../../components/common/item_icon_view.dart';
import '../../../../models/player_model.dart';
import '../../../../models/inventory_model.dart';
import '../../../../providers/inventory_provider.dart';
import '../../../../theme/app_colors.dart';
import 'home_stat_badge.dart';

class HeroShowcase extends StatefulWidget {
  final PlayerProfile profile;
  final InventoryState inventoryState;
  final int totalPower;
  final int reputation;
  final void Function(String slotLabel, InventoryItem? item)? onSlotTap;

  const HeroShowcase({
    super.key,
    required this.profile,
    required this.inventoryState,
    required this.totalPower,
    required this.reputation,
    this.onSlotTap,
  });

  @override
  State<HeroShowcase> createState() => _HeroShowcaseState();
}

class _HeroShowcaseState extends State<HeroShowcase>
    with SingleTickerProviderStateMixin, LifecycleAnimationPause {
  late AnimationController _breathingController;

  @override
  AnimationController? get lifecycleAnimationController => _breathingController;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (AppForegroundService.instance.isForeground) {
      _breathingController.repeat(reverse: true);
    }
    attachLifecycleAnimationPause();
  }

  @override
  void dispose() {
    detachLifecycleAnimationPause();
    _breathingController.dispose();
    super.dispose();
  }

  final List<({String key, String label, IconData icon})> _equipSlots = const [
    (key: 'weapon', label: 'Silah', icon: Icons.gps_fixed),
    (key: 'head', label: 'Kask', icon: Icons.shield_moon_outlined),
    (key: 'chest', label: 'Zırh', icon: Icons.shield_outlined),
    (key: 'gloves', label: 'Eldiven', icon: Icons.back_hand_outlined),
    (key: 'legs', label: 'Bacak', icon: Icons.accessibility_new),
    (key: 'boots', label: 'Bot', icon: Icons.hiking_outlined),
    (key: 'necklace', label: 'Aksesuar', icon: Icons.diamond_outlined),
    (key: 'ring', label: 'Yüzük', icon: Icons.circle_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final List<({String key, String label, IconData icon})> leftSlots =
        _equipSlots.sublist(0, 4);
    final List<({String key, String label, IconData icon})> rightSlots =
        _equipSlots.sublist(4, 8);

    return RepaintBoundary(
      child: LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double showcaseHeight = (constraints.maxWidth * 1.05).clamp(320.0, 450.0);

        return SizedBox(
          height: showcaseHeight,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _breathingController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (_breathingController.value * 0.05),
                    child: Container(
                      width: 290,
                      height: 290,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF00B4FF).withValues(alpha: 0.2),
                            Colors.transparent,
                          ],
                          stops: const [0.2, 1.0],
                        ),
                      ),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _breathingController,
                builder: (context, child) {
                  String imageAsset = 'assets/characters/savasci.png';
                  if (widget.profile.characterClass == CharacterClass.shadow) {
                    imageAsset = 'assets/characters/golge.png';
                  } else if (widget.profile.characterClass ==
                      CharacterClass.alchemist) {
                    imageAsset = 'assets/characters/simyaci.png';
                  }

                  return Transform.translate(
                    offset: Offset(0, -8 * _breathingController.value),
                    child: Image.asset(
                      imageAsset,
                      height: showcaseHeight * 0.78,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.person_pin,
                        size: 200,
                        color: Color(0xFF00B4FF),
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                left: 8,
                top: 72,
                child: Column(
                  children: leftSlots.map((slot) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildEquipSlot(
                        widget.inventoryState.equippedItems[slot.key],
                        slot.icon,
                        slot.label,
                      ),
                    );
                  }).toList(),
                ),
              ),
              Positioned(
                right: 8,
                top: 72,
                child: Column(
                  children: rightSlots.map((slot) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildEquipSlot(
                        widget.inventoryState.equippedItems[slot.key],
                        slot.icon,
                        slot.label,
                      ),
                    );
                  }).toList(),
                ),
              ),
              Positioned(
                bottom: 14,
                child: _buildLevelBadge(widget.profile.level),
              ),
              Positioned(
                top: 6,
                left: 2,
                child: HomeStatBadge.power(
                  value: _compact(widget.totalPower),
                  compact: true,
                ),
              ),
              Positioned(
                top: 6,
                right: 2,
                child: HomeStatBadge.reputation(
                  reputation: widget.reputation,
                  compact: true,
                ),
              ),
            ],
          ),
        );
      },
    ),
    );
  }

  String _compact(int value) {
    if (value >= 1000000000) {
      return '${(value / 1000000000).toStringAsFixed(1)}B';
    }
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }

  Widget _buildLevelBadge(int level) {
    const Color gold = AppColors.liquidGold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.spaceNavy.withValues(alpha: 0.92),
            AppColors.carbonVoid.withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: 0.55)),
        boxShadow: <BoxShadow>[
          BoxShadow(color: gold.withValues(alpha: 0.28), blurRadius: 10),
        ],
      ),
      child: Text(
        'LVL $level',
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          shadows: <Shadow>[Shadow(color: gold, blurRadius: 6)],
        ),
      ),
    );
  }

  Widget _slotFallbackIcon(IconData icon) {
    return Icon(icon, size: 22, color: const Color(0xFF8A96A8));
  }

  Widget _buildEquipSlot(
    InventoryItem? equipped,
    IconData fallbackIcon,
    String type,
  ) {
    final bool isEmpty = equipped == null;
    final Widget slotBody = isEmpty
        ? Center(child: _slotFallbackIcon(fallbackIcon))
        : Tooltip(
            message: '$type: ${equipped.name}',
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: ItemIconView(
                  iconValue: equipped.icon,
                  itemId: equipped.itemId,
                  itemType: equipped.itemType,
                  size: 50,
                  expand: true,
                  fallback: '◻',
                ),
              ),
            ),
          );

    return GestureDetector(
      onTap: () => widget.onSlotTap?.call(type, equipped),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: const Color(0xFF080B12).withValues(alpha: 0.7),
          border: Border.all(
            color: isEmpty
                ? Colors.white24
                : const Color(0xFFFFB800).withValues(alpha: 0.8),
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: <BoxShadow>[
            if (!isEmpty)
              BoxShadow(
                color: const Color(0xFFFFB800).withValues(alpha: 0.4),
                blurRadius: 8,
              ),
            const BoxShadow(
              color: Colors.black54,
              blurRadius: 4,
              offset: Offset(2, 2),
            ),
          ],
        ),
        child: slotBody,
      ),
    );
  }
}
