import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/item_icon_view.dart';
import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../repositories/inventory_repository.dart';
import '../../routing/app_router.dart';
import '../../l10n/l10n.dart';
import '../../utils/logout_helper.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadInventory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final inventoryState = ref.watch(inventoryProvider);

    return Scaffold(
      appBar: GameTopBar(
        title: context.l10n.routeInventory,
        onLogout: () async {
          await performLogout(ref);
},
      ),
      extendBody: true,
      bottomNavigationBar: GameBottomBar(
        currentRoute: AppRoutes.inventory,
        onLogout: () async {
          await performLogout(ref);
},
      ),
      body: switch (inventoryState.status) {
        InventoryStatus.initial || InventoryStatus.loading => const Center(
          child: CircularProgressIndicator(),
        ),
        InventoryStatus.error => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(inventoryState.errorMessage ?? 'Envanter yuklenemedi.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () =>
                      ref.read(inventoryProvider.notifier).loadInventory(),
                  child: const Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        ),
        InventoryStatus.ready => _InventoryReadyView(state: inventoryState),
      },
    );
  }
}

class _InventoryReadyView extends StatelessWidget {
  const _InventoryReadyView({required this.state});

  final InventoryState state;

  @override
  Widget build(BuildContext context) {
    return _InventoryReadyInteractive(state: state);
  }
}

class _InventoryReadyInteractive extends ConsumerStatefulWidget {
  const _InventoryReadyInteractive({required this.state});

  final InventoryState state;

  @override
  ConsumerState<_InventoryReadyInteractive> createState() =>
      _InventoryReadyInteractiveState();
}

class _InventoryReadyInteractiveState
    extends ConsumerState<_InventoryReadyInteractive> {
  String? _selectedRowId;
  _InventoryFilter _activeFilter = _InventoryFilter.all;

  Future<void> _openItemActionsPopup(InventoryItem item) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 32,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 338),
            child: _SelectedItemPanel(
              item: item,
              onEquip: (it) async {
                await _handleEquip(it);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              onUse: (it) async {
                await _handleUse(it);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              onSell: (it) async {
                await _handleSell(it);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              onSplit: (it) async {
                await _handleSplit(it);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              onDelete: (it) async {
                await _handleDelete(it);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              onToggleFavorite: (it) async {
                await _handleToggleFavorite(it);
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              },
              isFavorite: item.isFavorite,
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppMessenger.show(context, message);
  }

  Future<void> _handleUnequip(String slot) async {
    final ok = await ref
        .read(inventoryProvider.notifier)
        .unequipItem(slot: slot);
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Islem basarisiz');
    }
  }

  Future<void> _handleEquip(InventoryItem item) async {
    final String slot = item.equipSlot.name;
    if (slot == 'none') return;

    final ok = await ref
        .read(inventoryProvider.notifier)
        .equipItem(rowId: item.rowId, slot: slot);

    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Kusanma basarisiz');
      return;
    }

    if (!mounted) return;
    setState(() {
      _selectedRowId = null;
    });
  }

  Future<void> _handleSwap(int fromSlot, int toSlot) async {
    if (fromSlot == toSlot) return;

    final ok = await ref
        .read(inventoryProvider.notifier)
        .swapSlots(fromSlot: fromSlot, toSlot: toSlot);

    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Slot degistirme basarisiz');
    }
  }

  Future<void> _handleMoveItemToSlot(String rowId, int targetSlot) async {
    final ok = await ref
        .read(inventoryProvider.notifier)
        .moveItemToSlot(rowId: rowId, targetSlot: targetSlot);
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Item tasima basarisiz');
    }
  }

  Future<void> _handleUnequipToSlot({
    required String rowId,
    required String equipSlot,
    required int targetSlot,
  }) async {
    final ok = await ref
        .read(inventoryProvider.notifier)
        .unequipItemToSlot(
          rowId: rowId,
          slot: equipSlot,
          targetSlot: targetSlot,
        );
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Kusanilan item hedef slota birakilamadi');
    }
  }

  Future<void> _handleSwapEquipWithSlot({
    required String equipSlot,
    required int targetSlot,
  }) async {
    final ok = await ref
        .read(inventoryProvider.notifier)
        .swapEquipWithSlot(equipSlot: equipSlot, targetSlot: targetSlot);
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Kusanilan item swap basarisiz');
    }
  }

  Future<void> _handleDropOnInventorySlot({
    required _DragPayload payload,
    required int targetSlot,
    required InventoryItem? targetItem,
  }) async {
    if (payload.item.isEquipped) {
      final String equipSlot = payload.equipSlot ?? payload.item.equippedSlot;
      if (equipSlot.isEmpty) {
        _showSnack('Kusanilan item slotu tespit edilemedi.');
        return;
      }

      if (targetItem == null) {
        await _handleUnequipToSlot(
          rowId: payload.item.rowId,
          equipSlot: equipSlot,
          targetSlot: targetSlot,
        );
        return;
      }

      await _handleSwapEquipWithSlot(
        equipSlot: equipSlot,
        targetSlot: targetSlot,
      );
      return;
    }

    final int fromSlot = payload.item.slotPosition;
    if (fromSlot == targetSlot) return;

    if (targetItem == null) {
      await _handleMoveItemToSlot(payload.item.rowId, targetSlot);
      return;
    }

    await _handleSwap(fromSlot, targetSlot);
  }

  Future<void> _handleDropOnEquipSlot({
    required _DragPayload payload,
    required String targetEquipSlot,
    required InventoryItem? occupiedInTarget,
  }) async {
    final String normalized = targetEquipSlot.toLowerCase();

    if (payload.item.equipSlot.name.toLowerCase() != normalized) {
      _showSnack('Bu item bu slota kusanamaz.');
      return;
    }

    if (payload.item.isEquipped) {
      if (payload.item.equippedSlot.toLowerCase() == normalized) return;
      _showSnack('Kusanili item baska kusan slotuna suruklenemez.');
      return;
    }

    if (occupiedInTarget != null &&
        occupiedInTarget.rowId != payload.item.rowId) {
      await _handleSwapEquipWithSlot(
        equipSlot: normalized,
        targetSlot: payload.item.slotPosition,
      );
      return;
    }

    await _handleEquip(payload.item);
  }

  Future<void> _handleUse(InventoryItem item) async {
    final bool canUse =
        item.itemType == ItemType.potion ||
        item.itemType == ItemType.consumable ||
        item.potionType != PotionType.none ||
        item.energyRestore > 0 ||
        item.healthRestore > 0;
    if (!canUse) {
      _showSnack('Bu item kullanilamaz.');
      return;
    }

    final UseItemResult result = await ref
        .read(inventoryProvider.notifier)
        .useItem(item: item);
    if (!result.success) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(result.message ?? error ?? 'Item kullanimi basarisiz.');
      return;
    }
    _showSnack(result.message ?? '${item.name} kullanildi.');
  }

  Future<void> _handleSell(InventoryItem item) async {
    if (!item.isTradeable) {
      _showSnack('Bu item satilamaz.');
      return;
    }

    final int? quantity = await showDialog<int>(
      context: context,
      builder: (context) => _QuantityActionDialog(
        title: 'Item Sat',
        subtitle: '${item.name} satmak istedigin miktari sec.',
        confirmLabel: 'Sat',
        unitValue: item.vendorSellPrice,
        maxQuantity: item.quantity,
      ),
    );

    if (quantity == null) return;
    final result = await ref
        .read(inventoryProvider.notifier)
        .sellItemByRow(rowId: item.rowId, quantity: quantity);
    if (!result.success) {
      _showSnack(result.error ?? 'Satis basarisiz.');
      return;
    }
    _showSnack(
      '$quantity adet ${item.name} satildi (+${result.goldEarned} altin).',
    );
  }

  Future<void> _handleSplit(InventoryItem item) async {
    if (!item.isStackable || item.quantity <= 1) {
      _showSnack('Bu item bolunemez.');
      return;
    }

    final int? quantity = await showDialog<int>(
      context: context,
      builder: (context) => _QuantityActionDialog(
        title: 'Stack Bol',
        subtitle: 'Yeni stack icin miktar sec.',
        confirmLabel: 'Bol',
        unitValue: 0,
        maxQuantity: item.quantity - 1,
        showTotalValue: false,
      ),
    );

    if (quantity == null) return;
    final bool ok = await ref
        .read(inventoryProvider.notifier)
        .splitStack(rowId: item.rowId, splitQuantity: quantity);
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Stack bolme basarisiz.');
      return;
    }
    _showSnack('$quantity adet ${item.name} ayrildi.');
  }

  Future<void> _handleDelete(InventoryItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item Sil'),
        content: Text(
          '${item.name} itemini cop kutusuna gondermek istiyor musun?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Iptal'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final bool ok = await ref
        .read(inventoryProvider.notifier)
        .trashItem(rowId: item.rowId);
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Silme basarisiz.');
      return;
    }
    _showSnack('${item.name} silindi.');
  }

  Future<void> _handleToggleFavorite(InventoryItem item) async {
    final bool target = !item.isFavorite;
    final bool ok = await ref
        .read(inventoryProvider.notifier)
        .toggleFavorite(rowId: item.rowId, isFavorite: target);
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Favori guncellenemedi.');
      return;
    }
    _showSnack(target ? 'Favorilere eklendi.' : 'Favorilerden cikarildi.');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final state = widget.state;
        final bool isWide = constraints.maxWidth >= 980;
        final int occupiedSlots = state.items
            .where((item) => !item.isEquipped)
            .length;

        return Stack(
          children: <Widget>[
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      Color(0xFF090D14),
                      Color(0xFF101722),
                      Color(0xFF090D14),
                    ],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: GameScrollLayout.withClearance(
                context,
                const EdgeInsets.all(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (isWide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 3,
                          child: _SectionCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                const Text(
                                  'Kusanilanlar',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 10),
                                _EquippedPanel(
                                  equippedItems: state.equippedItems,
                                  onUnequip: _handleUnequip,
                                  onDropToSlot: (payload, slotName, occupied) =>
                                      _handleDropOnEquipSlot(
                                        payload: payload,
                                        targetEquipSlot: slotName,
                                        occupiedInTarget: occupied,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 7,
                          child: _inventoryCard(state, occupiedSlots),
                        ),
                      ],
                    )
                  else ...<Widget>[
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Kusanilanlar',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 390),
                            child: _EquippedPanel(
                              equippedItems: state.equippedItems,
                              onUnequip: _handleUnequip,
                              onDropToSlot: (payload, slotName, occupied) =>
                                  _handleDropOnEquipSlot(
                                    payload: payload,
                                    targetEquipSlot: slotName,
                                    occupiedInTarget: occupied,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _inventoryCard(state, occupiedSlots),
                  ],
                  const SizedBox(height: 16),
                  const SizedBox(height: 0),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _inventoryCard(InventoryState state, int occupiedSlots) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'ENVANTER',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: Colors.white70,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: Text(
                  '$occupiedSlots/$inventoryCapacity',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _InventoryFilterBar(
            activeFilter: _activeFilter,
            onChanged: (filter) {
              setState(() {
                _activeFilter = filter;
              });
            },
          ),
          const SizedBox(height: 10),
          GameFixedGrid(
            crossAxisCount: 5,
            spacing: 8,
            itemCount: inventoryCapacity,
            itemBuilder: (context, index) {
              return AspectRatio(
                aspectRatio: 1,
                child: _buildInventorySlot(context, state, index),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInventorySlot(BuildContext context, InventoryState state, int index) {
    final rawItem = _getItemBySlot(state.items, index);
    final item = (rawItem != null && _matchesFilter(rawItem, _activeFilter)) ? rawItem : null;
    final card = _InventorySlotCard(
      item: item,
      slotIndex: index,
      isSelected: item != null && item.rowId == _selectedRowId,
      onTap: item == null
          ? null
          : () async {
              setState(() {
                _selectedRowId = item.rowId;
              });
              await _openItemActionsPopup(item);
            },
    );

    final Widget draggable = item == null
        ? card
        : LongPressDraggable<_DragPayload>(
            data: _DragPayload.fromInventory(item),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: 64,
                height: 64,
                child: _InventorySlotCard(
                  item: item,
                  slotIndex: index,
                  isSelected: false,
                  onTap: null,
                ),
              ),
            ),
            childWhenDragging: Opacity(opacity: 0.35, child: card),
            child: card,
          );

    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (!data.item.isEquipped && data.item.slotPosition == index) return false;
        if (data.item.isEquipped && data.item.equippedSlot.isEmpty) return false;
        return true;
      },
      onAcceptWithDetails: (details) => _handleDropOnInventorySlot(
        payload: details.data,
        targetSlot: index,
        targetItem: rawItem,
      ),
      builder: (context, candidateData, rejectedData) {
        final bool highlighted = candidateData.isNotEmpty;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: highlighted
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  )
                : null,
          ),
          child: draggable,
        );
      },
    );
  }

  bool _matchesFilter(InventoryItem item, _InventoryFilter filter) {
    switch (filter) {
      case _InventoryFilter.all:
        return true;
      case _InventoryFilter.weapon:
        return item.itemType == ItemType.weapon;
      case _InventoryFilter.armor:
        return item.itemType == ItemType.armor;
      case _InventoryFilter.potion:
        return item.itemType == ItemType.potion ||
            item.itemType == ItemType.consumable;
      case _InventoryFilter.material:
        return item.itemType == ItemType.material;
    }
  }

  InventoryItem? _getItemBySlot(List<InventoryItem> items, int slot) {
    for (final item in items) {
      if (item.slotPosition == slot) return item;
    }
    return null;
  }
}

enum _InventoryFilter { all, weapon, armor, potion, material }

class _InventoryFilterBar extends StatelessWidget {
  const _InventoryFilterBar({
    required this.activeFilter,
    required this.onChanged,
  });

  final _InventoryFilter activeFilter;
  final ValueChanged<_InventoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const filters = <(_InventoryFilter, String, String)>[
      (_InventoryFilter.all, 'Hepsi', '📦'),
      (_InventoryFilter.weapon, 'Silah', '⚔️'),
      (_InventoryFilter.armor, 'Zırh', '🛡️'),
      (_InventoryFilter.potion, 'İksir', '🧪'),
      (_InventoryFilter.material, 'Malzeme', '🪨'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((entry) {
          final bool selected = entry.$1 == activeFilter;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => onChanged(entry.$1),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: selected
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.16)
                      : Colors.white.withValues(alpha: 0.03),
                  border: Border.all(
                    color: selected
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.05),
                    width: selected ? 1.2 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entry.$3, style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 5),
                    Text(
                      entry.$2,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xF0141B26), Color(0xF0090D15)],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class _EquippedPanel extends StatelessWidget {
  const _EquippedPanel({
    required this.equippedItems,
    required this.onUnequip,
    required this.onDropToSlot,
  });

  final Map<String, InventoryItem?> equippedItems;
  final Future<void> Function(String slot) onUnequip;
  final Future<void> Function(
    _DragPayload payload,
    String slotName,
    InventoryItem? occupiedItem,
  )
  onDropToSlot;

  @override
  Widget build(BuildContext context) {
    const slots = <(String, String, IconData)>[
      ('weapon', 'SİLAH', Icons.gps_fixed),
      ('head', 'KAFA', Icons.shield_moon),
      ('chest', 'GÖĞÜS', Icons.checkroom),
      ('legs', 'BACAK', Icons.accessibility_new),
      ('boots', 'BOT', Icons.hiking),
      ('gloves', 'ELDİVEN', Icons.back_hand),
      ('ring', 'YÜZÜK', Icons.circle_outlined),
      ('necklace', 'KOLYE', Icons.diamond_outlined),
    ];

    return GameFixedGrid(
      crossAxisCount: 4,
      spacing: 8,
      itemCount: slots.length,
      itemBuilder: (BuildContext context, int index) {
        final (String, String, IconData) slotMeta = slots[index];
        final item = equippedItems[slotMeta.$1];
        final bool hasItem = item != null;
        final Color rarityColor = hasItem
            ? getRarityColor(item.rarity)
            : Colors.white24;

        final Widget slotBody = GestureDetector(
          onTap: hasItem ? () => onUnequip(slotMeta.$1) : null,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1424),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasItem
                    ? rarityColor.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.08),
                width: hasItem ? 1.8 : 1.0,
              ),
              boxShadow: [
                if (hasItem)
                  BoxShadow(
                    color: rarityColor.withValues(alpha: 0.15),
                    blurRadius: 6,
                    spreadRadius: 0,
                  ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                if (hasItem)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              rarityColor.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                            radius: 0.7,
                          ),
                        ),
                      ),
                    ),
                  ),
                Opacity(
                  opacity: hasItem ? 0.04 : 0.22,
                  child: Icon(slotMeta.$3, size: 24, color: Colors.white),
                ),
                if (hasItem)
                  Positioned.fill(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      child: Center(
                        child: ItemIconView(
                          iconValue: item.icon,
                          itemId: item.itemId,
                          itemType: item.itemType,
                          size: 38,
                          expand: true,
                        ),
                      ),
                    ),
                  ),
                if (!hasItem)
                  Positioned(
                    bottom: 4,
                    child: Text(
                      slotMeta.$2,
                      style: const TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white38,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                if (hasItem)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(
                      Icons.close_rounded,
                      size: 9,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                if (hasItem && item.enhancementLevel > 0)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xE6080D1A),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        '+${item.enhancementLevel}',
                        style: const TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFD700),
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        final Widget draggable = item == null
            ? slotBody
            : LongPressDraggable<_DragPayload>(
                data: _DragPayload.fromEquipped(item, slotMeta.$1),
                feedback: Material(
                  color: Colors.transparent,
                  child: SizedBox(width: 72, height: 72, child: slotBody),
                ),
                childWhenDragging: Opacity(opacity: 0.35, child: slotBody),
                child: slotBody,
              );

        return AspectRatio(
          aspectRatio: 1,
          child: DragTarget<_DragPayload>(
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) =>
                onDropToSlot(details.data, slotMeta.$1, item),
            builder: (context, candidateData, rejectedData) {
              final bool highlighted = candidateData.isNotEmpty;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: highlighted
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: draggable,
              );
            },
          ),
        );
      },
    );
  }
}

enum _DragSource { inventory, equipped }

class _DragPayload {
  const _DragPayload({
    required this.item,
    required this.source,
    this.equipSlot,
  });

  final InventoryItem item;
  final _DragSource source;
  final String? equipSlot;

  factory _DragPayload.fromInventory(InventoryItem item) {
    return _DragPayload(item: item, source: _DragSource.inventory);
  }

  factory _DragPayload.fromEquipped(InventoryItem item, String slot) {
    return _DragPayload(
      item: item,
      source: _DragSource.equipped,
      equipSlot: slot,
    );
  }
}

class _InventorySlotCard extends StatelessWidget {
  const _InventorySlotCard({
    required this.item,
    required this.slotIndex,
    required this.isSelected,
    required this.onTap,
  });

  final InventoryItem? item;
  final int slotIndex;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // ── Boş slot ──────────────────────────────────────────────────────────────
    if (item == null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0x15162235),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              '${slotIndex + 1}',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white12,
              ),
            ),
          ),
        ),
      );
    }

    final rarityColor = getRarityColor(item!.rarity);
    final Color borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : rarityColor.withValues(alpha: 0.45);
    final double borderWidth = isSelected ? 2.2 : 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: borderWidth),
          color: const Color(0xFF0D1424),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.25),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.08),
              blurRadius: 6,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            // 1. Sleek Background Rarity Aura Gradient
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        rarityColor.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                      center: Alignment.center,
                      radius: 0.7,
                    ),
                  ),
                ),
              ),
            ),

            // 2. High Quality Item Icon (Fully centered with safe bounds)
            Positioned.fill(
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Center(
                  child: ItemIconView(
                    iconValue: item!.icon,
                    itemId: item!.itemId,
                    itemType: item!.itemType,
                    size: 42,
                    expand: true,
                  ),
                ),
              ),
            ),

            // 3. Compact Icons & Badges Overlay
            if (item!.isFavorite)
              const Positioned(
                top: 4,
                left: 4,
                child: Icon(
                  Icons.star_rounded,
                  size: 11,
                  color: Colors.amber,
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),

            // Upgrade/Enhancement Level Badge (+5) - Knight Online Style in Top Right
            if (item!.enhancementLevel > 0)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xE6080D1A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                      width: 0.7,
                    ),
                  ),
                  child: Text(
                    '+${item!.enhancementLevel}',
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFFFD700),
                      height: 1.0,
                    ),
                  ),
                ),
              ),

            // Multi/Quantity badge overlay (Bottom Right side)
            if (item!.isStackable && item!.quantity > 1)
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xE6080D1A),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: rarityColor.withValues(alpha: 0.45),
                      width: 0.7,
                    ),
                  ),
                  child: Text(
                    'x${item!.quantity}',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: rarityColor,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedItemPanel extends StatelessWidget {
  const _SelectedItemPanel({
    required this.item,
    required this.onEquip,
    required this.onUse,
    required this.onSell,
    required this.onSplit,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _actionYellow = Color(0xFFF2D74C);
  static const Color _textPrimary = Color(0xFF111111);
  static const Color _textMuted = Color(0xFF999999);
  static const Color _textBody = Color(0xFF888888);
  static const Color _borderLight = Color(0xFFD4D4D4);

  final InventoryItem? item;
  final Future<void> Function(InventoryItem item) onEquip;
  final Future<void> Function(InventoryItem item) onUse;
  final Future<void> Function(InventoryItem item) onSell;
  final Future<void> Function(InventoryItem item) onSplit;
  final Future<void> Function(InventoryItem item) onDelete;
  final Future<void> Function(InventoryItem item) onToggleFavorite;
  final bool isFavorite;

  Widget _buildActionButton({
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
  }) {
    final bool disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: Ink(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: isPrimary
                ? (disabled ? const Color(0xFFE8E8E8) : _actionYellow)
                : _cardBg,
            border: isPrimary
                ? null
                : Border.all(
                    color: disabled ? const Color(0xFFEEEEEE) : _borderLight,
                    width: 1,
                  ),
            boxShadow: isPrimary && !disabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: _actionYellow.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: disabled ? const Color(0xFFBDBDBD) : _textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemIconWithShadow(InventoryItem item) {
    return SizedBox(
      width: 110,
      height: 110,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            bottom: 18,
            child: Container(
              width: 72,
              height: 14,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ItemIconView(
              iconValue: item.icon,
              itemId: item.itemId,
              itemType: item.itemType,
              size: 88,
              expand: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(List<(String, String)> stats) {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: stats.map((stat) {
        return Text(
          '${stat.$1}: ${stat.$2}',
          style: const TextStyle(
            color: _textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (item == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: const Text(
          'Bir item secin.',
          style: TextStyle(color: _textMuted, fontWeight: FontWeight.w600),
        ),
      );
    }

    final bool canEquip = item!.equipSlot != EquipSlot.none;
    final bool canUse =
        item!.itemType == ItemType.potion ||
        item!.itemType == ItemType.consumable ||
        item!.potionType != PotionType.none ||
        item!.energyRestore > 0 ||
        item!.healthRestore > 0;
    final bool canSell = item!.vendorSellPrice > 0;
    final bool canSplit = item!.isStackable && item!.quantity > 1;

    final stats = <(String, String)>[
      ('SALDIRI', '${item!.attack}'),
      ('SAVUNMA', '${item!.defense}'),
      ('GUC', '${item!.power}'),
      ('SEVIYE', 'Lv. ${item!.requiredLevel}'),
      ('DEGER', '${item!.vendorSellPrice}g'),
    ];

    final String primaryLabel;
    final VoidCallback? primaryAction;
    if (canUse) {
      primaryLabel = 'KULLAN';
      primaryAction = () => onUse(item!);
    } else if (canEquip) {
      primaryLabel = 'KUSAN (${item!.equipSlot.name.toUpperCase()})';
      primaryAction = () => onEquip(item!);
    } else {
      primaryLabel = 'KULLANILAMAZ';
      primaryAction = null;
    }

    final String footerRight = canSell
        ? '${item!.vendorSellPrice}g'
        : 'Lv. ${item!.requiredLevel}';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 40,
              offset: const Offset(0, 16),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildItemIconWithShadow(item!),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        _buildActionButton(
                          label: primaryLabel,
                          onPressed: primaryAction,
                          isPrimary: true,
                        ),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          label: 'BOL',
                          onPressed: canSplit ? () => onSplit(item!) : null,
                          isPrimary: false,
                        ),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          label: 'COP',
                          onPressed: () => onDelete(item!),
                          isPrimary: false,
                        ),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          label: 'SAT',
                          onPressed: canSell ? () => onSell(item!) : null,
                          isPrimary: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => onToggleFavorite(item!),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isFavorite
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: isFavorite
                              ? const Color(0xFFE6B800)
                              : _textMuted,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'ESYA ADI',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item!.name.toUpperCase(),
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${item!.rarity.name.toUpperCase()} · ${item!.equipSlot != EquipSlot.none ? item!.equipSlot.name.toUpperCase() : item!.itemType.name.toUpperCase()}',
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              if (item!.description.isNotEmpty)
                Text(
                  item!.description,
                  style: const TextStyle(
                    color: _textBody,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.55,
                  ),
                ),
              const SizedBox(height: 14),
              _buildStatsRow(stats),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Text(
                    'x${item!.quantity}',
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    footerRight,
                    style: const TextStyle(
                      color: _textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuantityActionDialog extends StatefulWidget {
  const _QuantityActionDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.unitValue,
    required this.maxQuantity,
    this.showTotalValue = true,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final int unitValue;
  final int maxQuantity;
  final bool showTotalValue;

  @override
  State<_QuantityActionDialog> createState() => _QuantityActionDialogState();
}

class _QuantityActionDialogState extends State<_QuantityActionDialog> {
  late int _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.maxQuantity < 1 ? 1 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final int total = widget.unitValue * _quantity;

    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(widget.subtitle),
          const SizedBox(height: 12),
          Text('Miktar: $_quantity / ${widget.maxQuantity}'),
          Slider(
            value: _quantity.toDouble(),
            min: 1,
            max: widget.maxQuantity.toDouble(),
            divisions: widget.maxQuantity > 1 ? widget.maxQuantity - 1 : null,
            onChanged: widget.maxQuantity <= 1
                ? null
                : (value) {
                    setState(() {
                      _quantity = value.round();
                    });
                  },
          ),
          if (widget.showTotalValue)
            Text(
              'Toplam Deger: $total',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Iptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_quantity),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
