import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/item_icon_view.dart';
import '../../components/common/holo_foil_sheen.dart';
import '../../components/common/app_messenger.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../providers/box_opening_provider.dart';
import 'widgets/inventory_item_detail_flow.dart';
import 'widgets/inventory_power_badge.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_inventory_target.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(boxOpeningProvider.notifier).load();
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.inventory);
      if (mounted) _syncEquipCoachBypass();
    });
  }

  /// No unequipped gear → Devam (can't spotlight empty inventory / equip).
  void _syncEquipCoachBypass() {
    if (!mounted) return;
    final TutorialState tut = ref.read(tutorialProvider);
    final String? stepId = tut.activeStep?.id;
    final TutorialController ctrl = ref.read(tutorialProvider.notifier);

    if (stepId == 'enhance_open_item' || stepId == 'enhance_equip') {
      final bool hasEquippable =
          TutorialInventoryTarget.lootEquippableRowId(widget.state) != null;
      if (!hasEquippable) {
        ctrl.setCoachBypass(
          enabled: true,
          body: context.l10n.tut_enhance_bypass_no_equip_body,
        );
      } else {
        ctrl.setCoachBypass(enabled: false);
      }
      return;
    }

    if (tut.forceShowManualCta) {
      ctrl.setCoachBypass(enabled: false);
    }
  }

  /// open_item Devam (boş çanta) → enhance_equip'i de atla (ikinci Devam yok).
  Future<void> _maybeAutoSkipEmptyEquip(String? previous, String? next) async {
    if (previous != 'enhance_open_item' || next != 'enhance_equip') return;
    if (TutorialInventoryTarget.lootEquippableRowId(widget.state) != null) {
      return;
    }
    final TutorialController ctrl = ref.read(tutorialProvider.notifier);
    ctrl.setCoachBypass(
      enabled: true,
      body: context.l10n.tut_enhance_bypass_no_equip_body,
    );
    await ctrl.completeActiveManual();
  }

  Future<void> _openItemActionsPopup(InventoryItem item) async {
    if (!mounted) return;
    await _itemDetailFlow.open(item);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    AppMessenger.show(context, message);
  }

  Future<void> _openEquippedItemInfo(InventoryItem item) async {
    await _openItemActionsPopup(item);
  }

  Future<void> _handleUnequip(String slot) async {
    if (!ref.read(inventoryProvider.notifier).canDirectUnequip()) {
      _showSnack('Envanter dolu — benzer slottaki esyayla degistir');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Kuşanı çıkar'),
          content: const Text('Bu eşyayı çıkarmak istiyor musun?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Çıkar'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

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

    final int playerLevel = ref.read(playerProvider).profile?.level ?? 1;
    if (playerLevel < item.requiredLevel) {
      _showSnack('Level yetersiz. Gereken: ${item.requiredLevel}');
      return;
    }

    final InventoryItem? occupied =
        ref.read(inventoryProvider).equippedItems[slot];
    final bool ok = occupied != null
        ? await ref.read(inventoryProvider.notifier).swapEquipWithSlot(
              equipSlot: slot,
              targetSlot: item.slotPosition,
            )
        : await ref
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

  InventoryItemDetailFlow get _itemDetailFlow => InventoryItemDetailFlow(
        context: context,
        ref: ref,
        source: 'inventory',
        onEquipSuccess: () {
          if (mounted) {
            setState(() => _selectedRowId = null);
          }
          unawaited(TutorialTriggers.onEquipSuccess(ref));
        },
      );

  Future<void> _handleBoxClaim(BoxOpening opening) =>
      _itemDetailFlow.claimOpening(opening);

  Future<void> _handleBoxCancel(BoxOpening opening) =>
      _itemDetailFlow.cancelOpening(opening);

  @override
  Widget build(BuildContext context) {
    ref.watch(tutorialProvider.select((TutorialState s) => s.activeStep?.id));
    ref.listen<String?>(
      tutorialProvider.select((TutorialState s) => s.activeStep?.id),
      (String? previous, String? next) {
        unawaited(_maybeAutoSkipEmptyEquip(previous, next));
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncEquipCoachBypass();
    });

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
                                const Align(
                                  alignment: Alignment.center,
                                  child: InventoryPowerBadge(),
                                ),
                                const SizedBox(height: 10),
                                _EquippedPanel(
                                  equippedItems: state.equippedItems,
                                  onUnequip: _handleUnequip,
                                  onTapEquipped: _openEquippedItemInfo,
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
                          const Align(
                            alignment: Alignment.center,
                            child: InventoryPowerBadge(),
                          ),
                          const SizedBox(height: 10),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 390),
                            child: _EquippedPanel(
                              equippedItems: state.equippedItems,
                              onUnequip: _handleUnequip,
                              onTapEquipped: _openEquippedItemInfo,
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
                  const SizedBox(height: 12),
                  _BoxOpeningPanel(
                    onClaim: _handleBoxClaim,
                    onCancel: _handleBoxCancel,
                  ),
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

  String? _tutorialLootEquippableRowId(InventoryState state) =>
      TutorialInventoryTarget.lootEquippableRowId(state);

  Widget _buildInventorySlot(BuildContext context, InventoryState state, int index) {
    final rawItem = _getItemBySlot(state.items, index);
    final item = (rawItem != null && _matchesFilter(rawItem, _activeFilter)) ? rawItem : null;
    Future<void> openSlot() async {
      if (item == null) return;
      final bool isTutorialLoot =
          item.rowId == _tutorialLootEquippableRowId(state);
      final TutorialStepV2? activeStep =
          ref.read(tutorialProvider).activeStep;
      if (isTutorialLoot &&
          activeStep?.anchorId == TutorialAnchorId.inventoryFirstWeapon) {
        await TutorialTriggers.onAnchorTap(
          ref,
          TutorialAnchorId.inventoryFirstWeapon,
        );
      }
      setState(() {
        _selectedRowId = item.rowId;
      });
      // Always open detail. Old gate (`enhance_equip || !isTutorialLoot`)
      // skipped popup for highest-slot gear even when tutorial inactive —
      // vault/distributed equippables looked "untappable".
      await _openItemActionsPopup(item);
    }

    final card = _InventorySlotCard(
      item: item,
      slotIndex: index,
      isSelected: item != null && item.rowId == _selectedRowId,
      onTap: item == null ? null : openSlot,
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
            child: HoloFoilRarityBox(
              rarity: item.rarity,
              enhancementLevel: item.enhancementLevel,
              borderRadius: BorderRadius.circular(12),
              child: card,
            ),
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
        final Widget slot = DecoratedBox(
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
        final String? tutorialLootRow = _tutorialLootEquippableRowId(state);
        if (item != null && item.rowId == tutorialLootRow) {
          return TutorialAnchorScope(
            id: TutorialAnchorId.inventoryFirstWeapon,
            // Overlay hole catcher — DragTarget/LongPressDraggable block
            // fall-through taps during spotlight.
            onTutorialTap: openSlot,
            child: slot,
          );
        }
        return slot;
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
    // Prefer O(1) map from provider state when list matches current snapshot.
    final InventoryItem? mapped = ref.read(inventoryProvider).itemsBySlot[slot];
    if (mapped != null) return mapped;
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
    required this.onTapEquipped,
    required this.onDropToSlot,
  });

  final Map<String, InventoryItem?> equippedItems;
  final Future<void> Function(String slot) onUnequip;
  final Future<void> Function(InventoryItem item) onTapEquipped;
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
          onTap: hasItem ? () => onTapEquipped(item!) : null,
          onLongPress: hasItem ? () => onUnequip(slotMeta.$1) : null,
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
                child: HoloFoilRarityBox(
                  rarity: item.rarity,
                  enhancementLevel: item.enhancementLevel,
                  borderRadius: BorderRadius.circular(12),
                  child: slotBody,
                ),
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

// ── Kutu açılma paneli ───────────────────────────────────────────────────────

class _BoxOpeningPanel extends ConsumerStatefulWidget {
  const _BoxOpeningPanel({required this.onClaim, required this.onCancel});

  final Future<void> Function(BoxOpening opening) onClaim;
  final Future<void> Function(BoxOpening opening) onCancel;

  @override
  ConsumerState<_BoxOpeningPanel> createState() => _BoxOpeningPanelState();
}

class _BoxOpeningPanelState extends ConsumerState<_BoxOpeningPanel> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(boxOpeningProvider).isNotEmpty) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _countdown(BoxOpening opening) {
    final Duration left = opening.opensAt.difference(DateTime.now().toUtc());
    if (left.isNegative) return 'HAZIR';
    final int m = left.inMinutes;
    final int s = left.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final List<BoxOpening> openings = ref.watch(boxOpeningProvider);
    if (openings.isEmpty) return const SizedBox.shrink();

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            '⏳ AÇILAN KUTULAR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 10),
          ...openings.map((BoxOpening opening) {
            final bool ready = opening.isReady;
            final Color accent =
                ready ? const Color(0xFF22C55E) : const Color(0xFFF5C842);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: <Widget>[
                  Text(ready ? '🎁' : '📦',
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          opening.boxName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          ready ? 'Açıldı — ödülünü al!' : _countdown(opening),
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => widget.onCancel(opening),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Color(0xFFEF4444)),
                    tooltip: 'Sil (ödül iptal)',
                  ),
                  if (ready)
                    FilledButton(
                      onPressed: () => widget.onClaim(opening),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 34),
                      ),
                      child: const Text(
                        'Ödülü Al',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
