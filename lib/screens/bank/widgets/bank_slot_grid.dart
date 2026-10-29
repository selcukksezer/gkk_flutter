import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../models/inventory_model.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: rarityColor.withValues(alpha: 0.08),
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 0.85,
            colors: <Color>[
              rarityColor.withValues(alpha: 0.20),
              rarityColor.withValues(alpha: 0.02),
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.16),
              blurRadius: 8,
              spreadRadius: -2,
            ),
          ],
        ),
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
    this.onDragStarted,
    this.onDragUpdate,
    this.onDragEnd,
    this.tutorialAnchorId,
  });

  final InventoryItem? item;
  final int globalSlotIndex;
  final bool isDragTargetActive;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDragStarted;
  final DragUpdateCallback? onDragUpdate;
  final DragEndCallback? onDragEnd;
  final String? tutorialAnchorId;

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
      isRoyalVault: false,
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
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      feedback: Material(
        color: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black54,
        child: SizedBox(
          width: 76,
          height: 88,
          child: slotBody,
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: interactive),
      child: tutorialAnchorId == null
          ? interactive
          : TutorialAnchorScope(id: tutorialAnchorId!, child: interactive),
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
    this.unlockGemCost,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDragEnd,
  });

  final Map<String, dynamic>? item;
  final int globalSlotIndex;
  final bool isLocked;
  final bool isDragTargetActive;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final int? unlockGemCost;
  final VoidCallback? onDragStarted;
  final DragUpdateCallback? onDragUpdate;
  final DragEndCallback? onDragEnd;

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
      lockedUnlockCost: isLocked ? unlockGemCost : null,
      isRoyalVault: true,
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
      onDragStarted: onDragStarted,
      onDragUpdate: onDragUpdate,
      onDragEnd: onDragEnd,
      feedback: Material(
        color: Colors.transparent,
        elevation: 6,
        shadowColor: Colors.black54,
        child: SizedBox(
          width: 76,
          height: 88,
          child: slotBody,
        ),
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
    this.lockedUnlockCost,
    this.isRoyalVault = false,
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
  final int? lockedUnlockCost;
  final bool isRoyalVault;

  @override
  Widget build(BuildContext context) {
    Color effectiveBorderColor;
    double borderWidth = 1.0;
    if (isDragTargetActive) {
      effectiveBorderColor = BankDesign.crystalCyan;
      borderWidth = 1.8;
    } else if (isSelected) {
      effectiveBorderColor = selectedColor;
      borderWidth = 1.8;
    } else if (isLocked) {
      effectiveBorderColor = Colors.white.withValues(alpha: 0.08);
    } else if (hasItem) {
      effectiveBorderColor = rarityColor.withValues(alpha: 0.55);
      borderWidth = 1.2;
    } else {
      effectiveBorderColor = Colors.white.withValues(alpha: 0.06);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: effectiveBorderColor,
          width: borderWidth,
        ),
        gradient: isLocked
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFF0F141F),
                  Color(0xFF070A10),
                ],
              )
            : isDragTargetActive
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  BankDesign.crystalCyan.withValues(alpha: 0.28),
                  BankDesign.crystalCyan.withValues(alpha: 0.08),
                ],
              )
            : isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  selectedColor.withValues(alpha: 0.24),
                  selectedColor.withValues(alpha: 0.08),
                ],
              )
            : hasItem
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  isRoyalVault ? const Color(0xFF1B2332) : AppColors.spaceNavy,
                  const Color(0xFF0C1019),
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  BankDesign.royalObsidian.withValues(alpha: 0.65),
                  BankDesign.royalObsidianDeep.withValues(alpha: 0.85),
                ],
              ),
        boxShadow: isDragTargetActive
            ? <BoxShadow>[
                BoxShadow(
                  color: BankDesign.crystalCyan.withValues(alpha: 0.45),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : isSelected
            ? <BoxShadow>[
                BoxShadow(
                  color: selectedColor.withValues(alpha: 0.38),
                  blurRadius: 10,
                  spreadRadius: 0.5,
                ),
              ]
            : hasItem
            ? <BoxShadow>[
                BoxShadow(
                  color: rarityColor.withValues(alpha: 0.18),
                  blurRadius: 8,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: isLocked
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(4.5),
                        decoration: BoxDecoration(
                          color: BankDesign.gold.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: BankDesign.royalGoldFiligree
                                .withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: BankDesign.royalGoldFiligree
                              .withValues(alpha: 0.85),
                        ),
                      ),
                      if (lockedUnlockCost != null) ...<Widget>[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                BankDesign.crystalCyan.withValues(alpha: 0.2),
                                BankDesign.crystalCyan.withValues(alpha: 0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: BankDesign.crystalCyan
                                  .withValues(alpha: 0.45),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                '$lockedUnlockCost',
                                style: const TextStyle(
                                  color: BankDesign.crystalCyan,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(width: 1.5),
                              const Text(
                                '💎',
                                style: TextStyle(fontSize: 8),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 1),
                        const Text(
                          'Aç',
                          style: TextStyle(
                            color: BankDesign.gold,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                      const SizedBox(height: 1),
                      Text(
                        '#${globalSlotIndex + 1}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                          fontSize: 7.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : hasItem
          ? Stack(
              fit: StackFit.expand,
              children: <Widget>[
                // Subtle top specular highlight for 2027 dark-glass curvature
                Positioned(
                  top: 0,
                  left: 6,
                  right: 6,
                  height: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Item Visual
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(3, 3, 3, 17),
                    child: BankItemIcon(
                      icon: icon,
                      rarityColor: rarityColor,
                      itemId: itemId,
                    ),
                  ),
                ),

                // Name Pill
                Positioned(
                  left: 2.5,
                  right: 2.5,
                  bottom: 2.5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          const Color(0xFF111724).withValues(alpha: 0.95),
                          const Color(0xFF080B12).withValues(alpha: 0.98),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: isSelected
                            ? selectedColor.withValues(alpha: 0.6)
                            : rarityColor.withValues(alpha: 0.35),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? selectedColor
                            : Colors.white.withValues(alpha: 0.95),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),

                // Quantity Chip
                if (quantity > 1)
                  Positioned(
                    left: 3,
                    top: 3,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 36),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0A0E17).withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFFFBBF24).withValues(alpha: 0.8),
                            width: 0.8,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$quantity',
                            style: const TextStyle(
                              color: Color(0xFFFDE68A),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Upgrade / Enhancement Level
                if (upgradeLevel > 0)
                  Positioned(
                    right: 3,
                    top: 3,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 32),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[
                              BankDesign.royalGoldFiligree,
                              BankDesign.goldDim,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: BankDesign.gold.withValues(alpha: 0.45),
                              blurRadius: 4,
                              spreadRadius: 0.5,
                            ),
                          ],
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '+$upgradeLevel',
                            style: const TextStyle(
                              color: Color(0xFF0A0710),
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Selection Check Indicator (placed dynamically to avoid badge collisions)
                if (isSelected)
                  Positioned(
                    left: upgradeLevel > 0 ? 3 : null,
                    right: upgradeLevel > 0 ? null : 3,
                    top: 3,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selectedColor,
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: selectedColor.withValues(alpha: 0.6),
                            blurRadius: 4,
                            spreadRadius: 0.5,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check,
                          size: 9,
                          color: AppColors.carbonVoid,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.add,
                    color: isDragTargetActive
                        ? BankDesign.crystalCyan
                        : Colors.white.withValues(alpha: 0.12),
                    size: 15,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#${globalSlotIndex + 1}',
                    style: TextStyle(
                      color: isDragTargetActive
                          ? BankDesign.crystalCyan.withValues(alpha: 0.7)
                          : Colors.white.withValues(alpha: 0.18),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
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
    if (itemCount <= 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = BankDesign.gridColumns;
        final double spacing = BankDesign.gridSpacing;
        final double safeWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : 320.0;
        final double cellWidth =
            ((safeWidth - spacing * (columns - 1)) / columns).clamp(36.0, 120.0);
        final double cellHeight =
            (cellWidth / BankDesign.slotAspectRatio).clamp(44.0, 140.0);

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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _BankPageButton(
            icon: Icons.chevron_left_rounded,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(currentPage - 1),
            tooltip: 'Önceki sayfa',
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  BankDesign.royalObsidian.withValues(alpha: 0.85),
                  BankDesign.royalObsidianDeep.withValues(alpha: 0.95),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: BankDesign.royalGoldFiligree.withValues(alpha: 0.35),
                width: 1.0,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: BankDesign.gold.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Sayfa ',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '$currentPage',
                  style: const TextStyle(
                    color: BankDesign.goldLight,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  ' / $totalPages',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _BankPageButton(
            icon: Icons.chevron_right_rounded,
            enabled: currentPage < totalPages,
            onTap: () => onPageChanged(currentPage + 1),
            tooltip: 'Sonraki sayfa',
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
    this.tooltip,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: enabled
                ? BankDesign.royalObsidian.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: enabled
                  ? BankDesign.royalGoldFiligree.withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.06),
              width: 1.0,
            ),
            boxShadow: enabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: BankDesign.gold.withValues(alpha: 0.08),
                      blurRadius: 6,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? BankDesign.goldLight : Colors.white24,
          ),
        ),
      ),
    );
  }
}
