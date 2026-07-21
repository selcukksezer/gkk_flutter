import 'package:flutter/material.dart';
import '../../../../core/services/app_foreground_service.dart';
import '../../../../components/common/item_icon_view.dart';
import '../../../../models/player_model.dart';
import '../../../../models/inventory_model.dart';
import '../../../../providers/inventory_provider.dart';

class HeroShowcase extends StatefulWidget {
  final PlayerProfile profile;
  final InventoryState inventoryState;
  final int totalPower;
  final int reputation;
  final void Function(InventoryItem item)? onEquippedTap;

  const HeroShowcase({
    super.key,
    required this.profile,
    required this.inventoryState,
    required this.totalPower,
    required this.reputation,
    this.onEquippedTap,
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
                bottom: 14,
                child: _buildBadge(
                  "LVL ${widget.profile.level}",
                  const Color(0xFFFFB800),
                ),
              ),
              Positioned(
                top: 16,
                left: 36,
                child: _buildBadge(
                  'POWER',
                  const Color(0xFFE01E5A),
                  _compact(widget.totalPower),
                ),
              ),
              Positioned(
                top: 16,
                right: 36,
                child: _buildBadge(
                  'REP',
                  const Color(0xFF8A2BE2),
                  _compact(widget.reputation),
                ),
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

  Widget _buildBadge(String text, Color color, [String? value]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF121826).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              shadows: <Shadow>[Shadow(color: color, blurRadius: 4)],
            ),
          ),
          if (value != null)
            Text(
              value,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
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
      onTap: equipped != null ? () => widget.onEquippedTap?.call(equipped) : null,
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
