import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../models/inventory_model.dart';
import '../../../theme/app_colors.dart';
import 'bank_design.dart';

class BankItemIcon extends StatelessWidget {
  const BankItemIcon({
    super.key,
    required this.icon,
    required this.rarityColor,
    this.itemId,
  });

  final String icon;
  final Color rarityColor;
  final String? itemId;

  @override
  Widget build(BuildContext context) {
    final String value = icon.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        decoration: BoxDecoration(color: rarityColor.withValues(alpha: 0.08)),
        child: ItemIconView(
          iconValue: value,
          itemId: itemId,
          size: 56,
          expand: true,
          fallback: '📦',
        ),
      ),
    );
  }
}

class BankInventorySlot extends StatelessWidget {
  const BankInventorySlot({
    super.key,
    required this.item,
    required this.globalSlotIndex,
    required this.isDragTargetActive,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final InventoryItem? item;
  final int globalSlotIndex;
  final bool isDragTargetActive;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final bool hasItem = item != null;
    final Color rarityColor = hasItem
        ? AppColors.forRarity(item!.rarity.name)
        : Colors.white24;

    final Widget slotBody = _BankSlotBody(
      hasItem: hasItem,
      isLocked: false,
      isDragTargetActive: isDragTargetActive,
      isSelected: isSelected,
      selectedColor: BankDesign.deposit,
      rarityColor: rarityColor,
      globalSlotIndex: globalSlotIndex,
      name: hasItem ? item!.name : '',
      quantity: hasItem ? item!.quantity : 0,
      upgradeLevel: hasItem ? item!.enhancementLevel : 0,
      icon: hasItem ? item!.icon : '',
      itemId: hasItem ? item!.itemId : null,
    );

    final Widget interactive = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: slotBody,
    );

    if (!hasItem) return interactive;

    final BankDragPayload payload = BankDragPayload(
      sourceType: BankDragSourceType.inventory,
      sourceId: item!.rowId,
      itemId: item!.itemId,
      name: item!.name,
      quantity: item!.quantity,
      isStackable: item!.isStackable,
    );

    return LongPressDraggable<BankDragPayload>(
      data: payload,
      delay: const Duration(milliseconds: 120),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 74, height: 86, child: slotBody),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: interactive),
      child: interactive,
    );
  }
}

class BankStorageSlot extends StatelessWidget {
  const BankStorageSlot({
    super.key,
    required this.item,
    required this.globalSlotIndex,
    required this.isLocked,
    required this.isDragTargetActive,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final Map<String, dynamic>? item;
  final int globalSlotIndex;
  final bool isLocked;
  final bool isDragTargetActive;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final bool hasItem = item != null;
    final Color rarityColor = hasItem
        ? AppColors.forRarity(item!['rarity']?.toString() ?? '')
        : Colors.white24;
    final int qty = hasItem ? bankAsInt(item!['quantity']) : 0;
    final int upgradeLevel = hasItem
        ? bankAsInt(
            item!['upgrade_level'],
            fallback: bankAsInt(item!['upgradeLevel']),
          )
        : 0;

    final Widget slotBody = _BankSlotBody(
      hasItem: hasItem,
      isLocked: isLocked,
      isDragTargetActive: isDragTargetActive,
      isSelected: isSelected,
      selectedColor: BankDesign.withdraw,
      rarityColor: rarityColor,
      globalSlotIndex: globalSlotIndex,
      name: hasItem ? item!['name']?.toString() ?? '' : '',
      quantity: qty,
      upgradeLevel: upgradeLevel,
      icon: hasItem ? item!['icon']?.toString() ?? '' : '',
      itemId: hasItem ? item!['item_id']?.toString() : null,
    );

    final Widget interactive = GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: slotBody,
    );

    if (!hasItem || isLocked) return interactive;

    final String id = item!['id']?.toString() ?? '';
    final String itemId = item!['item_id']?.toString() ?? '';
    final String name = item!['name']?.toString() ?? 'Eşya';

    final BankDragPayload payload = BankDragPayload(
      sourceType: BankDragSourceType.bank,
      sourceId: id,
      itemId: itemId,
      name: name,
      quantity: qty,
      isStackable: bankRowIsStackable(item!),
    );

    return LongPressDraggable<BankDragPayload>(
      data: payload,
      delay: const Duration(milliseconds: 120),
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 74, height: 86, child: slotBody),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: interactive),
      child: interactive,
    );
  }
}

class _BankSlotBody extends StatelessWidget {
  const _BankSlotBody({
    required this.hasItem,
    required this.isLocked,
    required this.isDragTargetActive,
    required this.isSelected,
    required this.selectedColor,
    required this.rarityColor,
    required this.globalSlotIndex,
    required this.name,
    required this.quantity,
    required this.upgradeLevel,
    required this.icon,
    this.itemId,
  });

  final bool hasItem;
  final bool isLocked;
  final bool isDragTargetActive;
  final bool isSelected;
  final Color selectedColor;
  final Color rarityColor;
  final int globalSlotIndex;
  final String name;
  final int quantity;
  final int upgradeLevel;
  final String icon;
  final String? itemId;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isLocked
              ? Colors.white12
              : isDragTargetActive
              ? BankDesign.deposit
              : isSelected
              ? selectedColor
              : hasItem
              ? rarityColor.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.08),
          width: isDragTargetActive ? 1.8 : 1,
        ),
        color: isLocked
            ? AppColors.carbonVoid.withValues(alpha: 0.65)
            : isDragTargetActive
            ? BankDesign.deposit.withValues(alpha: 0.12)
            : isSelected
            ? selectedColor.withValues(alpha: isSelected && selectedColor == BankDesign.withdraw ? 0.1 : 0.08)
            : hasItem
            ? AppColors.spaceNavy
            : AppColors.darkObsidian.withValues(alpha: 0.35),
      ),
      child: isLocked
          ? const Center(child: Text('🔒', style: TextStyle(fontSize: 16)))
          : hasItem
          ? Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: BankItemIcon(
                      icon: icon,
                      rarityColor: rarityColor,
                      itemId: itemId,
                    ),
                  ),
                ),
                Positioned(
                  left: 3,
                  right: 3,
                  bottom: 3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
                ),
                if (quantity > 1)
                  Positioned(
                    left: 4,
                    bottom: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFFBBF24).withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        '$quantity',
                        style: const TextStyle(
                          color: Color(0xFFFBBF24),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (upgradeLevel > 0)
                  Positioned(
                    right: 4,
                    top: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBBF24),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '+$upgradeLevel',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 4,
                  top: 3,
                  child: Text(
                    '#${globalSlotIndex + 1}',
                    style: const TextStyle(color: Colors.white24, fontSize: 9),
                  ),
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.add, color: Colors.white12, size: 14),
                  Text(
                    '#${globalSlotIndex + 1}',
                    style: const TextStyle(color: Colors.white12, fontSize: 9),
                  ),
                ],
              ),
            ),
    );
  }
}

class BankFixedSlotGrid extends StatelessWidget {
  const BankFixedSlotGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = BankDesign.gridColumns;
        final double spacing = BankDesign.gridSpacing;
        final double cellWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        final double cellHeight = cellWidth / BankDesign.slotAspectRatio;

        final List<Widget> cells = List<Widget>.generate(
          itemCount,
          (int index) => SizedBox(
            height: cellHeight,
            child: itemBuilder(context, index),
          ),
        );

        return GameGridColumns(
          crossAxisCount: columns,
          spacing: spacing,
          children: cells,
        );
      },
    );
  }
}

class BankPageControls extends StatelessWidget {
  const BankPageControls({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _BankPageButton(
            icon: Icons.chevron_left_rounded,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.darkObsidian.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: BankDesign.gold.withValues(alpha: 0.28),
              ),
            ),
            child: Text(
              'Sayfa $currentPage / $totalPages',
              style: const TextStyle(
                color: BankDesign.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _BankPageButton(
            icon: Icons.chevron_right_rounded,
            enabled: currentPage < totalPages,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }
}

class _BankPageButton extends StatelessWidget {
  const _BankPageButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: enabled
                ? BankDesign.gold.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled
                  ? BankDesign.gold.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Icon(
            icon,
            size: 22,
            color: enabled ? BankDesign.gold : Colors.white24,
          ),
        ),
      ),
    );
  }
}
