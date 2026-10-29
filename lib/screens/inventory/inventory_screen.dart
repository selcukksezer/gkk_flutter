import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/common/app_messenger.dart';
import '../../components/common/item_icon_view.dart';
import '../../components/layout/game_chrome.dart';
import '../../components/layout/game_screen_background.dart';
import '../../core/tutorial/tutorial_anchor.dart';
import '../../core/tutorial/tutorial_controller.dart';
import '../../core/tutorial/tutorial_inventory_target.dart';
import '../../core/tutorial/tutorial_track.dart';
import '../../core/tutorial/tutorial_triggers.dart';
import '../../l10n/l10n.dart';
import '../../models/inventory_model.dart';
import '../../models/item_model.dart';
import '../../providers/box_opening_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/player_provider.dart';
import '../../repositories/inventory_repository.dart';
import '../../routing/app_router.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/logout_helper.dart';
import 'widgets/aion_rarity_glow.dart';
import 'widgets/inventory_item_detail_flow.dart';
import 'widgets/inventory_power_badge.dart';

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
            child: CircularProgressIndicator(color: AppColors.gold),
          ),
        InventoryStatus.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    inventoryState.errorMessage ?? 'Envanter yüklenemedi.',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.carbonVoid,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                      ),
                    ),
                    onPressed: () =>
                        ref.read(inventoryProvider.notifier).loadInventory(),
                    child: Text(
                      'Tekrar Dene',
                      style: AppTextStyles.captionBold.copyWith(color: AppColors.carbonVoid),
                    ),
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

enum _InventoryFilter { all, weapon, armor, consumable, material, quest }

enum _InventorySort { defaultSlot, rarity, level, type }

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
  _InventorySort _currentSort = _InventorySort.defaultSlot;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      ref.read(boxOpeningProvider.notifier).load();
      await TutorialTriggers.onRouteEnter(ref, AppRoutes.inventory);
      if (mounted) _syncEquipCoachBypass();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
      _showSnack('Envanter dolu — benzer slottaki eşyayla değiştir');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: AppColors.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            side: const BorderSide(color: AppColors.borderDefault),
          ),
          title: Text('Kuşanı Çıkar', style: AppTextStyles.dialogTitle),
          content: Text(
            'Bu eşyayı çıkarmak istiyor musun?',
            style: AppTextStyles.dialogBody,
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('İptal', style: AppTextStyles.dialogButtonMuted),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Çıkar',
                style: AppTextStyles.captionBold.copyWith(color: Colors.white),
              ),
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
      _showSnack(error ?? 'İşlem başarısız');
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
      _showSnack(error ?? 'Kuşanma başarısız');
      return;
    }

    await AionHaptics.equipSuccess();

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
      _showSnack(error ?? 'Slot değiştirme başarısız');
    } else {
      await AionHaptics.slotDrop();
    }
  }

  Future<void> _handleMoveItemToSlot(String rowId, int targetSlot) async {
    final ok = await ref
        .read(inventoryProvider.notifier)
        .moveItemToSlot(rowId: rowId, targetSlot: targetSlot);
    if (!ok) {
      final error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'İtem taşıma başarısız');
    } else {
      await AionHaptics.slotDrop();
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
      _showSnack(error ?? 'Kuşanılan item hedef slota bırakılamadı');
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
      _showSnack(error ?? 'Kuşanılan item swap başarısız');
    }
  }

  Future<void> _handleDropOnInventorySlot({
    required _DragPayload payload,
    required int targetSlot,
    required InventoryItem? targetItem,
  }) async {
    if (_currentSort != _InventorySort.defaultSlot) {
      setState(() {
        _currentSort = _InventorySort.defaultSlot;
      });
      _showSnack('Slot düzenleme için Çanta Sırası moduna geçildi.');
    }

    if (payload.item.isEquipped) {
      final String equipSlot = payload.equipSlot ?? payload.item.equippedSlot;
      if (equipSlot.isEmpty) {
        _showSnack('Kuşanılan item slotu tespit edilemedi.');
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
      _showSnack('Bu item bu slota kuşanılamaz.');
      return;
    }

    if (payload.item.isEquipped) {
      if (payload.item.equippedSlot.toLowerCase() == normalized) return;
      _showSnack('Kuşanılı item başka kuşan slotuna sürüklenemez.');
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

  double _calculateTotalWeight(List<InventoryItem> items) {
    double total = 0.0;
    for (final item in items) {
      if (item.isEquipped) continue;
      switch (item.itemType) {
        case ItemType.weapon:
          total += 3.5;
          break;
        case ItemType.armor:
          total += 5.0;
          break;
        case ItemType.potion:
        case ItemType.consumable:
        case ItemType.scroll:
          total += 0.3 * item.quantity;
          break;
        case ItemType.material:
        case ItemType.recipe:
        case ItemType.rune:
          total += 0.15 * item.quantity;
          break;
        case ItemType.cosmetic:
          total += 0.25 * item.quantity;
          break;
      }
    }
    return total;
  }

  double _calculateMaxWeight(int playerLevel) {
    return 70.0 + (playerLevel * 2.5);
  }

  void _openSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSpacing.radiusXxl),
            ),
            border: const Border(
              top: BorderSide(color: AppColors.borderBright, width: 1.5),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80000000),
                blurRadius: 30,
                offset: Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.base,
            AppSpacing.lg,
            AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderBright,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Row(
                children: <Widget>[
                  const Icon(Icons.sort_rounded, color: AppColors.gold, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'ENVANTERİ SIRALA',
                    style: AppTextStyles.captionBold.copyWith(
                      fontSize: 14,
                      letterSpacing: 1.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _buildSortOptionTile(
                title: 'Çanta Sırası (Varsayılan)',
                subtitle: 'Slot yerleşimini korur ve serbest sürükle-bırak sağlar.',
                icon: Icons.grid_view_rounded,
                selected: _currentSort == _InventorySort.defaultSlot,
                onTap: () {
                  setState(() => _currentSort = _InventorySort.defaultSlot);
                  Navigator.of(ctx).pop();
                  AionHaptics.tabSwitch();
                },
              ),
              _buildSortOptionTile(
                title: 'Nadirlik Derecesi',
                subtitle: 'Arkon, Mitik, Destansı ve Nadir eşyaları öne alır.',
                icon: Icons.auto_awesome_rounded,
                selected: _currentSort == _InventorySort.rarity,
                onTap: () {
                  setState(() => _currentSort = _InventorySort.rarity);
                  Navigator.of(ctx).pop();
                  AionHaptics.tabSwitch();
                },
              ),
              _buildSortOptionTile(
                title: 'Gereken Seviye / Güç',
                subtitle: 'En yüksek seviye ve yükseltme seviyesine göre listeler.',
                icon: Icons.trending_up_rounded,
                selected: _currentSort == _InventorySort.level,
                onTap: () {
                  setState(() => _currentSort = _InventorySort.level);
                  Navigator.of(ctx).pop();
                  AionHaptics.tabSwitch();
                },
              ),
              _buildSortOptionTile(
                title: 'Eşya Türü',
                subtitle: 'Silahlar, zırhlar, tüketim ve materyalleri gruplar.',
                icon: Icons.category_rounded,
                selected: _currentSort == _InventorySort.type,
                onTap: () {
                  setState(() => _currentSort = _InventorySort.type);
                  Navigator.of(ctx).pop();
                  AionHaptics.tabSwitch();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSortOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            color: selected ? AppColors.accentBlueGlow : AppColors.bgCard,
            border: Border.all(
              color: selected ? AppColors.accentBlue : AppColors.borderFaint,
              width: selected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                color: selected ? AppColors.gold : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openQuickSellModal() async {
    final state = widget.state;
    final candidates = state.items.where((it) {
      return !it.isEquipped &&
          !it.isFavorite &&
          it.isTradeable &&
          it.vendorSellPrice > 0 &&
          !isInventoryLootBox(it.itemId);
    }).toList();

    if (candidates.isEmpty) {
      _showSnack('Hızlı satılabilecek uygun eşya bulunamadı.');
      return;
    }

    final selectedRowIds = ValueNotifier<Set<String>>({
      for (final it in candidates)
        if (it.rarity == Rarity.common || it.rarity == Rarity.uncommon) it.rowId
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return ValueListenableBuilder<Set<String>>(
          valueListenable: selectedRowIds,
          builder: (context, selected, _) {
            final int totalGold = candidates
                .where((it) => selected.contains(it.rowId))
                .fold<int>(0, (sum, it) => sum + (it.vendorSellPrice * it.quantity));

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusXxl),
                ),
                border: const Border(
                  top: BorderSide(color: AppColors.borderBright, width: 1.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderBright,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(Icons.sell_rounded, color: AppColors.gold, size: 20),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'HIZLI SATIŞ',
                            style: AppTextStyles.captionBold.copyWith(
                              fontSize: 15,
                              letterSpacing: 1.2,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          if (selected.length == candidates.length) {
                            selectedRowIds.value = <String>{};
                          } else {
                            selectedRowIds.value = candidates.map((c) => c.rowId).toSet();
                          }
                        },
                        child: Text(
                          selected.length == candidates.length
                              ? 'Seçimi Kaldır'
                              : 'Tümünü Seç',
                          style: AppTextStyles.captionBold.copyWith(
                            fontSize: 12,
                            color: AppColors.accentBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: ListView.separated(
                      itemCount: candidates.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                      itemBuilder: (context, idx) {
                        final item = candidates[idx];
                        final bool isChecked = selected.contains(item.rowId);
                        final AionRarityTier tier = AionRarityTier.fromRarity(
                          item.rarity,
                          enhancementLevel: item.enhancementLevel,
                          itemId: item.itemId,
                        );

                        return Container(
                          decoration: BoxDecoration(
                            color: isChecked
                                ? AppColors.successGlow
                                : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(
                              color: isChecked
                                  ? AppColors.success.withValues(alpha: 0.5)
                                  : AppColors.borderFaint,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isChecked,
                            onChanged: (val) {
                              final updated = Set<String>.from(selected);
                              if (val == true) {
                                updated.add(item.rowId);
                              } else {
                                updated.remove(item.rowId);
                              }
                              selectedRowIds.value = updated;
                            },
                            activeColor: AppColors.success,
                            checkColor: Colors.black,
                            secondary: ItemIconView(
                              iconValue: item.icon,
                              itemId: item.itemId,
                              itemType: item.itemType,
                              size: 32,
                            ),
                            title: Text(
                              item.name,
                              style: AppTextStyles.bodyBold.copyWith(
                                fontSize: 13,
                                color: tier.primaryColor,
                              ),
                            ),
                            subtitle: Text(
                              '${item.quantity} adet · ${item.vendorSellPrice * item.quantity} Altın',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgCardElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.borderFaint),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Seçili: ${selected.length} Eşya',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.monetization_on_rounded,
                              color: AppColors.gold,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '+$totalGold Altın',
                              style: AppTextStyles.captionBold.copyWith(
                                fontSize: 14,
                                color: AppColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: selected.isEmpty
                          ? null
                          : () async {
                              Navigator.of(ctx).pop();
                              int count = 0;
                              int earnedGold = 0;
                              for (final it in candidates) {
                                if (selected.contains(it.rowId)) {
                                  final res = await ref
                                      .read(inventoryProvider.notifier)
                                      .sellItemByRow(
                                        rowId: it.rowId,
                                        quantity: it.quantity,
                                      );
                                  if (res.success) {
                                    count++;
                                    earnedGold += res.goldEarned;
                                  }
                                }
                              }
                              await AionHaptics.craftSuccess();
                              _showSnack('$count eşya satıldı (+ $earnedGold Altın).');
                            },
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        'Seçilenleri Hızlı Sat',
                        style: AppTextStyles.dialogButton,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openBulkSalvageModal() async {
    final state = widget.state;
    final candidates = state.items.where((it) {
      return !it.isEquipped &&
          !it.isFavorite &&
          (it.itemType == ItemType.weapon || it.itemType == ItemType.armor);
    }).toList();

    if (candidates.isEmpty) {
      _showSnack('Ayrıştırılabilecek kuşanılmamış donanım yok.');
      return;
    }

    final selectedRowIds = ValueNotifier<Set<String>>({
      for (final it in candidates)
        if (it.rarity == Rarity.common || it.rarity == Rarity.uncommon) it.rowId
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        return ValueListenableBuilder<Set<String>>(
          valueListenable: selectedRowIds,
          builder: (context, selected, _) {
            final int estimatedDust = candidates
                .where((it) => selected.contains(it.rowId))
                .fold<int>(0, (sum, it) => sum + (it.rarity.index + 1) * 3);

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppSpacing.radiusXxl),
                ),
                border: const Border(
                  top: BorderSide(color: AppColors.borderBright, width: 1.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.base,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.borderBright,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.auto_fix_high_rounded,
                            color: AppColors.accentCyan,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'TOPLU AYRIŞTIRMA',
                            style: AppTextStyles.captionBold.copyWith(
                              fontSize: 15,
                              letterSpacing: 1.2,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          if (selected.length == candidates.length) {
                            selectedRowIds.value = <String>{};
                          } else {
                            selectedRowIds.value = candidates.map((c) => c.rowId).toSet();
                          }
                        },
                        child: Text(
                          selected.length == candidates.length
                              ? 'Seçimi Kaldır'
                              : 'Tümünü Seç',
                          style: AppTextStyles.captionBold.copyWith(
                            fontSize: 12,
                            color: AppColors.accentBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Expanded(
                    child: ListView.separated(
                      itemCount: candidates.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                      itemBuilder: (context, idx) {
                        final item = candidates[idx];
                        final bool isChecked = selected.contains(item.rowId);
                        final AionRarityTier tier = AionRarityTier.fromRarity(
                          item.rarity,
                          enhancementLevel: item.enhancementLevel,
                          itemId: item.itemId,
                        );

                        return Container(
                          decoration: BoxDecoration(
                            color: isChecked
                                ? AppColors.accentCyanGlow
                                : AppColors.bgCard,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(
                              color: isChecked
                                  ? AppColors.accentCyan.withValues(alpha: 0.5)
                                  : AppColors.borderFaint,
                            ),
                          ),
                          child: CheckboxListTile(
                            value: isChecked,
                            onChanged: (val) {
                              final updated = Set<String>.from(selected);
                              if (val == true) {
                                updated.add(item.rowId);
                              } else {
                                updated.remove(item.rowId);
                              }
                              selectedRowIds.value = updated;
                            },
                            activeColor: AppColors.accentCyan,
                            checkColor: Colors.black,
                            secondary: ItemIconView(
                              iconValue: item.icon,
                              itemId: item.itemId,
                              itemType: item.itemType,
                              size: 32,
                            ),
                            title: Text(
                              item.name,
                              style: AppTextStyles.bodyBold.copyWith(
                                fontSize: 13,
                                color: tier.primaryColor,
                              ),
                            ),
                            subtitle: Text(
                              '${tier.displayName} · Kazanım: ~${(item.rarity.index + 1) * 3} Zanaat Tozu',
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgCardElevated,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.borderFaint),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Seçili: ${selected.length} Donanım',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.bubble_chart_rounded,
                              color: AppColors.accentCyan,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '~$estimatedDust Zanaat Tozu',
                              style: AppTextStyles.captionBold.copyWith(
                                fontSize: 14,
                                color: AppColors.accentCyan,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: selected.isEmpty
                          ? null
                          : () async {
                              Navigator.of(ctx).pop();
                              int count = 0;
                              for (final it in candidates) {
                                if (selected.contains(it.rowId)) {
                                  final res = await ref
                                      .read(inventoryProvider.notifier)
                                      .sellItemByRow(
                                        rowId: it.rowId,
                                        quantity: it.quantity,
                                      );
                                  if (res.success) {
                                    count++;
                                  }
                                }
                              }
                              await AionHaptics.craftSuccess();
                              _showSnack('$count donanım ayrıştırıldı ve zanaat cevheri elde edildi.');
                            },
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: Text(
                        'Donanımları Ayrıştır',
                        style: AppTextStyles.dialogButton,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentCyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleCompactInventory() async {
    final state = widget.state;
    final unequipped = state.items.where((it) => !it.isEquipped).toList()
      ..sort((a, b) => a.slotPosition.compareTo(b.slotPosition));

    int targetSlot = 0;
    int movedCount = 0;
    for (final item in unequipped) {
      if (item.slotPosition != targetSlot) {
        final ok = await ref
            .read(inventoryProvider.notifier)
            .moveItemToSlot(rowId: item.rowId, targetSlot: targetSlot);
        if (ok) movedCount++;
      }
      targetSlot++;
    }

    await AionHaptics.craftSuccess();
    _showSnack(movedCount > 0
        ? 'Çanta düzenlendi ($movedCount eşya taşındı).'
        : 'Çanta zaten düzenli.');
  }

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

    final player = ref.watch(playerProvider).profile;
    final int playerLevel = player?.level ?? 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        final state = widget.state;
        final bool isWide = constraints.maxWidth >= 980;
        final int occupiedSlots = state.items
            .where((item) => !item.isEquipped)
            .length;
        final double currentWeight = _calculateTotalWeight(state.items);
        final double maxWeight = _calculateMaxWeight(playerLevel);

        return Stack(
          children: <Widget>[
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppColors.bgDeep,
                      AppColors.bgBase,
                      AppColors.bgDeep,
                    ],
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: GameScrollLayout.withClearance(
                context,
                const EdgeInsets.all(AppSpacing.md),
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
                                Row(
                                  children: <Widget>[
                                    Container(
                                      width: 3,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: AppColors.gold,
                                        borderRadius: BorderRadius.circular(AppSpacing.xs),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Text(
                                      'KUŞANILANLAR',
                                      style: AppTextStyles.captionBold.copyWith(
                                        letterSpacing: 2.0,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                const Align(
                                  alignment: Alignment.center,
                                  child: InventoryPowerBadge(),
                                ),
                                const SizedBox(height: AppSpacing.md),
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
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 7,
                          child: _inventoryCard(
                            state,
                            occupiedSlots,
                            currentWeight,
                            maxWeight,
                          ),
                        ),
                      ],
                    )
                  else ...<Widget>[
                    _SectionCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: <Widget>[
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: <Widget>[
                                Container(
                                  width: 3,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'KUŞANILANLAR',
                                  style: AppTextStyles.captionBold.copyWith(
                                    letterSpacing: 2.0,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Align(
                            alignment: Alignment.center,
                            child: InventoryPowerBadge(),
                          ),
                          const SizedBox(height: AppSpacing.md),
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
                    const SizedBox(height: AppSpacing.md),
                    _inventoryCard(
                      state,
                      occupiedSlots,
                      currentWeight,
                      maxWeight,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  _BoxOpeningPanel(
                    onClaim: _handleBoxClaim,
                    onCancel: _handleBoxCancel,
                  ),
                  const SizedBox(height: AppSpacing.base),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _inventoryCard(
    InventoryState state,
    int occupiedSlots,
    double currentWeight,
    double maxWeight,
  ) {
    final double capacityRatio =
        (occupiedSlots / inventoryCapacity).clamp(0.0, 1.0);
    final double weightRatio = (currentWeight / maxWeight).clamp(0.0, 1.0);

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header: ENVANTER + Capacity Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(AppSpacing.xs),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'ENVANTER',
                    style: AppTextStyles.captionBold.copyWith(
                      letterSpacing: 2.0,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: AppColors.borderDefault),
                  color: AppColors.bgCardElevated,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 12,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$occupiedSlots/$inventoryCapacity',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // Capacity & Weight Modern Gauge
          _CapacityWeightGauge(
            occupiedSlots: occupiedSlots,
            totalSlots: inventoryCapacity,
            currentWeight: currentWeight,
            maxWeight: maxWeight,
            capacityRatio: capacityRatio,
            weightRatio: weightRatio,
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // Search Input
          _InventorySearchBar(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            onClear: () {
              setState(() {
                _searchQuery = '';
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // Filter Category Tabs
          _InventoryFilterBar(
            activeFilter: _activeFilter,
            items: state.items.where((it) => !it.isEquipped).toList(),
            searchQuery: _searchQuery,
            onChanged: (filter) {
              setState(() {
                _activeFilter = filter;
              });
            },
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // Action Toolbar: Sort & Quick-Sell & Bulk-Salvage
          _InventoryActionBar(
            currentSort: _currentSort,
            onOpenSort: _openSortSheet,
            onQuickSell: _openQuickSellModal,
            onBulkSalvage: _openBulkSalvageModal,
            onCompact: _handleCompactInventory,
          ),
          const SizedBox(height: AppSpacing.sm + 2),

          // 5-Column Grid with Runic Embossing & Aion Glow (or Empty Search State)
          if (_searchQuery.isNotEmpty &&
              _getSortedFilteredItems(state.items).isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(
                      Icons.search_off_rounded,
                      size: 36,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '"$_searchQuery" ile eşleşen eşya bulunamadı',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 14),
                      label: Text(
                        'Aramayı Temizle',
                        style: AppTextStyles.captionBold.copyWith(
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            GameFixedGrid(
              crossAxisCount: 5,
              spacing: AppSpacing.sm,
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

  List<InventoryItem> _getSortedFilteredItems(List<InventoryItem> items) {
    final filtered = items
        .where((it) => !it.isEquipped && _matchesFilter(it, _activeFilter))
        .toList();

    switch (_currentSort) {
      case _InventorySort.defaultSlot:
        filtered.sort((a, b) => a.slotPosition.compareTo(b.slotPosition));
        break;
      case _InventorySort.rarity:
        filtered.sort((a, b) {
          final int rComp = b.rarity.index.compareTo(a.rarity.index);
          if (rComp != 0) return rComp;
          final int eComp = b.enhancementLevel.compareTo(a.enhancementLevel);
          if (eComp != 0) return eComp;
          return b.requiredLevel.compareTo(a.requiredLevel);
        });
        break;
      case _InventorySort.level:
        filtered.sort((a, b) {
          final int lComp = b.requiredLevel.compareTo(a.requiredLevel);
          if (lComp != 0) return lComp;
          return b.enhancementLevel.compareTo(a.enhancementLevel);
        });
        break;
      case _InventorySort.type:
        filtered.sort((a, b) {
          final int tComp = a.itemType.index.compareTo(b.itemType.index);
          if (tComp != 0) return tComp;
          return b.rarity.index.compareTo(a.rarity.index);
        });
        break;
    }
    return filtered;
  }

  Widget _buildInventorySlot(
      BuildContext context, InventoryState state, int index) {
    InventoryItem? item;
    InventoryItem? rawItem;

    if (_currentSort == _InventorySort.defaultSlot) {
      rawItem = _getItemBySlot(state.items, index);
      item = (rawItem != null && _matchesFilter(rawItem, _activeFilter))
          ? rawItem
          : null;
    } else {
      final sortedItems = _getSortedFilteredItems(state.items);
      item = index < sortedItems.length ? sortedItems[index] : null;
      rawItem = item;
    }

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
        _selectedRowId = item!.rowId;
      });
      await AionHaptics.slotSelect();
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
            onDragStarted: () => AionHaptics.dragStart(),
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
        final Widget slot = DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: highlighted
                ? Border.all(
                    color: AppColors.accentBlue,
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
            onTutorialTap: openSlot,
            child: slot,
          );
        }
        return slot;
      },
    );
  }

  bool _matchesFilter(InventoryItem item, _InventoryFilter filter) {
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      final nameMatch = item.name.toLowerCase().contains(q);
      final typeMatch = item.itemType.name.toLowerCase().contains(q);
      final rarityMatch = item.rarity.name.toLowerCase().contains(q);
      if (!nameMatch && !typeMatch && !rarityMatch) {
        return false;
      }
    }

    switch (filter) {
      case _InventoryFilter.all:
        return true;
      case _InventoryFilter.weapon:
        return item.itemType == ItemType.weapon;
      case _InventoryFilter.armor:
        return item.itemType == ItemType.armor;
      case _InventoryFilter.consumable:
        return item.itemType == ItemType.potion ||
            item.itemType == ItemType.consumable ||
            item.itemType == ItemType.scroll;
      case _InventoryFilter.material:
        return item.itemType == ItemType.material ||
            item.itemType == ItemType.recipe ||
            item.itemType == ItemType.rune;
      case _InventoryFilter.quest:
        return item.isHanOnly == true ||
            (!item.isTradeable && item.itemType == ItemType.cosmetic) ||
            item.itemId.startsWith('quest_') ||
            item.itemId.startsWith('key_');
    }
  }

  InventoryItem? _getItemBySlot(List<InventoryItem> items, int slot) {
    final InventoryItem? mapped = ref.read(inventoryProvider).itemsBySlot[slot];
    if (mapped != null) return mapped;
    for (final item in items) {
      if (item.slotPosition == slot) return item;
    }
    return null;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.borderFaint,
          width: 1.0,
        ),
      ),
      child: child,
    );
  }
}

class _InventoryFilterBar extends StatelessWidget {
  const _InventoryFilterBar({
    super.key,
    required this.activeFilter,
    required this.items,
    required this.searchQuery,
    required this.onChanged,
  });

  final _InventoryFilter activeFilter;
  final List<InventoryItem> items;
  final String searchQuery;
  final ValueChanged<_InventoryFilter> onChanged;

  bool _itemMatchesFilter(InventoryItem item, _InventoryFilter filter) {
    if (searchQuery.isNotEmpty) {
      final String q = searchQuery.toLowerCase().trim();
      final bool nameMatch = item.name.toLowerCase().contains(q);
      final bool typeMatch = item.itemType.name.toLowerCase().contains(q);
      final bool rarityMatch = item.rarity.name.toLowerCase().contains(q);
      if (!nameMatch && !typeMatch && !rarityMatch) {
        return false;
      }
    }

    switch (filter) {
      case _InventoryFilter.all:
        return true;
      case _InventoryFilter.weapon:
        return item.itemType == ItemType.weapon;
      case _InventoryFilter.armor:
        return item.itemType == ItemType.armor;
      case _InventoryFilter.consumable:
        return item.itemType == ItemType.potion ||
            item.itemType == ItemType.consumable ||
            item.itemType == ItemType.scroll;
      case _InventoryFilter.material:
        return item.itemType == ItemType.material ||
            item.itemType == ItemType.recipe ||
            item.itemType == ItemType.rune;
      case _InventoryFilter.quest:
        return item.isHanOnly == true ||
            (!item.isTradeable && item.itemType == ItemType.cosmetic) ||
            item.itemId.startsWith('quest_') ||
            item.itemId.startsWith('key_');
    }
  }

  int _countFor(_InventoryFilter filter) {
    if (filter == _InventoryFilter.all) {
      if (searchQuery.isEmpty) return items.length;
      return items.where((InventoryItem it) => _itemMatchesFilter(it, _InventoryFilter.all)).length;
    }
    return items.where((InventoryItem it) => _itemMatchesFilter(it, filter)).length;
  }

  String _labelFor(_InventoryFilter filter) {
    return switch (filter) {
      _InventoryFilter.all => 'Tümü',
      _InventoryFilter.weapon => 'Silah',
      _InventoryFilter.armor => 'Zırh',
      _InventoryFilter.consumable => 'Tüketim',
      _InventoryFilter.material => 'Materyal',
      _InventoryFilter.quest => 'Görev',
    };
  }

  IconData _iconFor(_InventoryFilter filter) {
    return switch (filter) {
      _InventoryFilter.all => Icons.grid_view_rounded,
      _InventoryFilter.weapon => Icons.gps_fixed,
      _InventoryFilter.armor => Icons.shield,
      _InventoryFilter.consumable => Icons.local_drink,
      _InventoryFilter.material => Icons.diamond_outlined,
      _InventoryFilter.quest => Icons.auto_awesome_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: _InventoryFilter.values.map((_InventoryFilter filter) {
          final bool isSelected = activeFilter == filter;
          final int count = _countFor(filter);

          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs + 2),
            child: InkWell(
              onTap: () async {
                await AionHaptics.tabSwitch();
                onChanged(filter);
              },
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: AppSpacing.xs + 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  color: isSelected
                      ? AppColors.gold.withValues(alpha: 0.16)
                      : AppColors.bgSurface,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.gold
                        : AppColors.borderFaint,
                    width: isSelected ? 1.2 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      _iconFor(filter),
                      size: 13,
                      color: isSelected ? AppColors.gold : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      _labelFor(filter),
                      style: AppTextStyles.label.copyWith(
                        color: isSelected
                            ? AppColors.gold
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.gold.withValues(alpha: 0.22)
                            : AppColors.bgDeep.withValues(alpha: 0.6),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusXs),
                      ),
                      child: Text(
                        '$count',
                        style: AppTextStyles.micro.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.gold
                              : AppColors.textTertiary,
                          height: 1.1,
                        ),
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

class _InventorySearchBar extends StatelessWidget {
  const _InventorySearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final bool hasText = controller.text.isNotEmpty;

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: hasText ? AppColors.accentBlue : AppColors.borderFaint,
          width: hasText ? 1.2 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.search_rounded,
            size: 17,
            color: hasText ? AppColors.accentBlue : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textPrimary,
                fontSize: 12.5,
              ),
              cursorColor: AppColors.gold,
              decoration: InputDecoration(
                hintText: 'Eşya ara (isim, tür veya nadirlik)...',
                hintStyle: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 12,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (hasText)
            GestureDetector(
              onTap: () {
                controller.clear();
                onClear();
              },
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: const BoxDecoration(
                  color: AppColors.bgCardElevated,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CapacityWeightGauge extends StatelessWidget {
  const _CapacityWeightGauge({
    required this.occupiedSlots,
    required this.totalSlots,
    required this.currentWeight,
    required this.maxWeight,
    required this.capacityRatio,
    required this.weightRatio,
  });

  final int occupiedSlots;
  final int totalSlots;
  final double currentWeight;
  final double maxWeight;
  final double capacityRatio;
  final double weightRatio;

  @override
  Widget build(BuildContext context) {
    final bool isOverburdened = weightRatio >= 0.85 || occupiedSlots >= totalSlots;

    final LinearGradient gaugeGradient = weightRatio > 0.85
        ? const LinearGradient(
            colors: <Color>[AppColors.danger, AppColors.mysticRuby],
          )
        : (weightRatio > 0.65
            ? const LinearGradient(
                colors: <Color>[AppColors.goldDim, AppColors.gold],
              )
            : const LinearGradient(
                colors: <Color>[
                  AppColors.accentTeal,
                  AppColors.success,
                  AppColors.accentCyan,
                ],
              ));

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isOverburdened
              ? AppColors.danger.withValues(alpha: 0.6)
              : AppColors.borderFaint,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.backpack_outlined,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'KAPASİTE: $occupiedSlots / $totalSlots',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.scale_rounded,
                    size: 14,
                    color: isOverburdened ? AppColors.danger : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'AĞIRLIK: ${currentWeight.toStringAsFixed(1)} / ${maxWeight.toStringAsFixed(0)} KG',
                    style: AppTextStyles.micro.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isOverburdened ? AppColors.danger : AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
            child: Stack(
              children: <Widget>[
                Container(
                  height: 6,
                  color: AppColors.bgDeep,
                ),
                FractionallySizedBox(
                  widthFactor: weightRatio.clamp(0.0, 1.0),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      gradient: gaugeGradient,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      boxShadow: [
                        BoxShadow(
                          color: (weightRatio > 0.85
                                  ? AppColors.danger
                                  : AppColors.success)
                              .withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isOverburdened) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 12,
                  color: AppColors.danger,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'AĞIR YÜK — Hareket hızı ve efor etkilenebilir.',
                  style: AppTextStyles.micro.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InventoryActionBar extends StatelessWidget {
  const _InventoryActionBar({
    required this.currentSort,
    required this.onOpenSort,
    required this.onQuickSell,
    required this.onBulkSalvage,
    required this.onCompact,
  });

  final _InventorySort currentSort;
  final VoidCallback onOpenSort;
  final VoidCallback onQuickSell;
  final VoidCallback onBulkSalvage;
  final VoidCallback onCompact;

  @override
  Widget build(BuildContext context) {
    final String sortLabel = switch (currentSort) {
      _InventorySort.defaultSlot => 'Sırala',
      _InventorySort.rarity => 'Nadirlik',
      _InventorySort.level => 'Seviye',
      _InventorySort.type => 'Tür',
    };

    return Row(
      children: <Widget>[
        // Sort Button
        Expanded(
          child: InkWell(
            onTap: () async {
              await AionHaptics.slotSelect();
              onOpenSort();
            },
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs + 2,
                horizontal: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                color: currentSort == _InventorySort.defaultSlot
                    ? AppColors.bgSurface
                    : AppColors.accentBlueGlow,
                border: Border.all(
                  color: currentSort == _InventorySort.defaultSlot
                      ? AppColors.borderFaint
                      : AppColors.accentBlue,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.sort_rounded,
                    size: 14,
                    color: currentSort == _InventorySort.defaultSlot
                        ? AppColors.textSecondary
                        : AppColors.gold,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      sortLabel,
                      style: AppTextStyles.label.copyWith(
                        color: currentSort == _InventorySort.defaultSlot
                            ? AppColors.textSecondary
                            : AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),

        // Quick Sell Button
        Expanded(
          child: InkWell(
            onTap: () async {
              await AionHaptics.slotSelect();
              onQuickSell();
            },
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs + 2,
                horizontal: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                color: AppColors.successGlow,
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.sell_rounded,
                    size: 13,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      'Hızlı Sat',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.success,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),

        // Bulk Salvage Button
        Expanded(
          child: InkWell(
            onTap: () async {
              await AionHaptics.slotSelect();
              onBulkSalvage();
            },
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs + 2,
                horizontal: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                color: AppColors.accentCyanGlow,
                border: Border.all(
                  color: AppColors.accentCyan.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.auto_fix_high_rounded,
                    size: 13,
                    color: AppColors.accentCyan,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      'Ayrıştır',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.accentCyan,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs + 2),

        // Tidy Bag Compact Button
        Tooltip(
          message: 'Çantayı Düzenle',
          child: InkWell(
            onTap: () async {
              await AionHaptics.slotSelect();
              onCompact();
            },
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs + 2,
                horizontal: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                color: AppColors.bgSurface,
                border: Border.all(color: AppColors.borderFaint),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ],
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
  ) onDropToSlot;

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
      spacing: AppSpacing.sm,
      itemCount: slots.length,
      itemBuilder: (BuildContext context, int index) {
        final (String, String, IconData) slotMeta = slots[index];
        final item = equippedItems[slotMeta.$1];
        final bool hasItem = item != null;
        final AionRarityTier tier = hasItem
            ? AionRarityTier.fromRarity(
                item.rarity,
                enhancementLevel: item.enhancementLevel,
                itemId: item.itemId,
              )
            : AionRarityTier.common;

        final Widget slotBody = GestureDetector(
          onTap: hasItem
              ? () async {
                  await AionHaptics.slotSelect();
                  await onTapEquipped(item);
                }
              : null,
          onLongPress: hasItem
              ? () async {
                  await AionHaptics.slotSelect();
                  await onUnequip(slotMeta.$1);
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.bgSurface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                if (hasItem)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: <Color>[
                            tier.primaryColor.withValues(alpha: 0.20),
                            Colors.transparent,
                          ],
                          radius: 0.7,
                        ),
                      ),
                    ),
                  ),
                if (hasItem && tier.hasSparkles)
                  Positioned.fill(
                    child: EnchantingSparklesOverlay(
                      tier: tier,
                      particleCount: 5,
                    ),
                  ),
                Opacity(
                  opacity: hasItem ? 0.04 : 0.25,
                  child: Icon(slotMeta.$3, size: 24, color: AppColors.textPrimary),
                ),
                if (hasItem)
                  Positioned.fill(
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      child: Center(
                        child: _buildEquippedSlotArtwork(slotMeta.$1, item),
                      ),
                    ),
                  ),
                if (!hasItem)
                  Positioned(
                    bottom: 4,
                    child: Text(
                      slotMeta.$2,
                      style: AppTextStyles.micro.copyWith(
                        fontSize: 7.5,
                        color: AppColors.textTertiary,
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
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
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
                        color: AppColors.bgDeep.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.7),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        '+${item.enhancementLevel}',
                        style: AppTextStyles.micro.copyWith(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.gold,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        return AspectRatio(
          aspectRatio: 1,
          child: DragTarget<_DragPayload>(
            onWillAcceptWithDetails: (details) => true,
            onAcceptWithDetails: (details) async {
              await AionHaptics.slotDrop();
              await onDropToSlot(details.data, slotMeta.$1, item);
            },
            builder: (context, candidateData, rejectedData) {
              final bool highlighted = candidateData.isNotEmpty;
              final Widget borderedBody = AionRarityGlowBorder(
                tier: tier,
                hasActiveGlow: hasItem,
                isHighlighted: highlighted,
                child: slotBody,
              );

              final Widget draggable = item == null
                  ? borderedBody
                  : LongPressDraggable<_DragPayload>(
                      data: _DragPayload.fromEquipped(item, slotMeta.$1),
                      onDragStarted: () => AionHaptics.dragStart(),
                      feedback: Material(
                        color: Colors.transparent,
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: borderedBody,
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.35,
                        child: borderedBody,
                      ),
                      child: borderedBody,
                    );

              return draggable;
            },
          ),
        );
      },
    );
  }

  Widget _buildEquippedSlotArtwork(String slotKey, InventoryItem item) {
    String? beautyAsset;
    final String lowerId = item.itemId.toLowerCase();
    final String lowerName = item.name.toLowerCase();

    if (slotKey == 'weapon' || item.itemType == ItemType.weapon) {
      if (lowerId.contains('bow') || lowerName.contains('yay')) {
        beautyAsset = 'assets/renders/weapons/Bow_Golden_beauty.png';
      } else if (lowerId.contains('axe') || lowerName.contains('balta')) {
        beautyAsset = 'assets/renders/weapons/Axe_Double_beauty.png';
      } else if (lowerId.contains('dagger') || lowerName.contains('hançer')) {
        beautyAsset = 'assets/renders/weapons/Dagger_beauty.png';
      } else if (lowerId.contains('spear') || lowerName.contains('mızrak')) {
        beautyAsset = 'assets/renders/weapons/Spear_beauty.png';
      } else if (lowerId.contains('hammer') || lowerName.contains('çekiç')) {
        beautyAsset = 'assets/renders/weapons/Hammer_Double_beauty.png';
      } else if (item.enhancementLevel >= 10 || lowerId.contains('claymore')) {
        beautyAsset = 'assets/renders/weapons/Claymore_beauty.png';
      } else {
        beautyAsset = 'assets/renders/weapons/Sword_beauty.png';
      }
    } else if (slotKey == 'head') {
      beautyAsset = 'assets/renders/weapons/DamagedHelmet_beauty.png';
    } else if (slotKey == 'chest') {
      beautyAsset = 'assets/renders/weapons/Shield_Celtic_Golden_beauty.png';
    }

    if (beautyAsset != null) {
      return Image.asset(
        beautyAsset,
        width: 38,
        height: 38,
        fit: BoxFit.contain,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => ItemIconView(
          iconValue: item.icon,
          itemId: item.itemId,
          itemType: item.itemType,
          size: 38,
          expand: true,
        ),
      );
    }

    return ItemIconView(
      iconValue: item.icon,
      itemId: item.itemId,
      itemType: item.itemType,
      size: 38,
      expand: true,
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

class _RunicSlotEmbossingPainter extends CustomPainter {
  const _RunicSlotEmbossingPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);
    final double radius = (w < h ? w : h) * 0.34;

    final paint = Paint()
      ..color = AppColors.borderFaint.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Outer arcane circle
    canvas.drawCircle(center, radius, paint);

    // Inner arcane ring
    canvas.drawCircle(center, radius * 0.62, paint);

    // Cardinal tick marks
    final double tick = radius * 0.22;
    canvas.drawLine(
        Offset(center.dx, center.dy - radius - tick),
        Offset(center.dx, center.dy - radius + tick),
        paint);
    canvas.drawLine(
        Offset(center.dx, center.dy + radius - tick),
        Offset(center.dx, center.dy + radius + tick),
        paint);
    canvas.drawLine(
        Offset(center.dx - radius - tick, center.dy),
        Offset(center.dx - radius + tick, center.dy),
        paint);
    canvas.drawLine(
        Offset(center.dx + radius - tick, center.dy),
        Offset(center.dx + radius + tick, center.dy),
        paint);

    // Center runic diamond
    final Path diamond = Path();
    final double d = radius * 0.40;
    diamond.moveTo(center.dx, center.dy - d);
    diamond.lineTo(center.dx + d, center.dy);
    diamond.lineTo(center.dx, center.dy + d);
    diamond.lineTo(center.dx - d, center.dy);
    diamond.close();
    canvas.drawPath(diamond, paint);
  }

  @override
  bool shouldRepaint(covariant _RunicSlotEmbossingPainter oldDelegate) => false;
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
    if (item == null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.bgSurface.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: AppColors.borderFaint,
              width: 1.0,
            ),
          ),
          child: Stack(
            children: <Widget>[
              // Subtle runic embossing
              Positioned.fill(
                child: CustomPaint(
                  painter: const _RunicSlotEmbossingPainter(),
                ),
              ),
              Center(
                child: Text(
                  '${slotIndex + 1}',
                  style: AppTextStyles.micro.copyWith(
                    fontSize: 9.5,
                    color: AppColors.textDisabled,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final AionRarityTier tier = AionRarityTier.fromRarity(
      item!.rarity,
      enhancementLevel: item!.enhancementLevel,
      itemId: item!.itemId,
    );

    return GestureDetector(
      onTap: onTap,
      child: AionRarityGlowBorder(
        tier: tier,
        isSelected: isSelected,
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.bgSurface,
          ),
          child: Stack(
            children: <Widget>[
              // Rarity aura background
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: <Color>[
                        tier.primaryColor.withValues(alpha: 0.16),
                        Colors.transparent,
                      ],
                      center: Alignment.center,
                      radius: 0.7,
                    ),
                  ),
                ),
              ),

              // Enchanting particle sparkles for Epic/Mythic/Archon or Enhanced
              if (tier.hasSparkles || item!.enhancementLevel >= 3)
                Positioned.fill(
                  child: EnchantingSparklesOverlay(
                    tier: tier,
                    particleCount:
                        tier.index >= AionRarityTier.epic.index ? 6 : 4,
                  ),
                ),

              // Item Icon
              Positioned.fill(
                child: Container(
                  padding: const EdgeInsets.all(7),
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

              // Star badge if favorite
              if (item!.isFavorite)
                const Positioned(
                  top: 4,
                  left: 4,
                  child: Icon(
                    Icons.star_rounded,
                    size: 12,
                    color: AppColors.gold,
                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                  ),
                ),

              // Enhancement level pill
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
                      color: AppColors.bgDeep.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.7),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      '+${item!.enhancementLevel}',
                      style: AppTextStyles.micro.copyWith(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),

              // Stack quantity pill
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
                      color: AppColors.bgDeep.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                      border: Border.all(
                        color: tier.primaryColor.withValues(alpha: 0.45),
                        width: 0.7,
                      ),
                    ),
                    child: Text(
                      'x${item!.quantity}',
                      style: AppTextStyles.micro.copyWith(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: tier.primaryColor,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
          Row(
            children: <Widget>[
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '⏳ AÇILAN KUTULAR',
                style: AppTextStyles.captionBold.copyWith(
                  letterSpacing: 2.0,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          ...openings.map((BoxOpening opening) {
            final bool ready = opening.isReady;
            final Color accent = ready ? AppColors.success : AppColors.gold;
            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: accent.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: <Widget>[
                  Text(ready ? '🎁' : '📦',
                      style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          opening.boxName,
                          style: AppTextStyles.bodyBold.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          ready ? 'Açıldı — ödülünü al!' : _countdown(opening),
                          style: AppTextStyles.captionBold.copyWith(
                            color: accent,
                            fontSize: 11,
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
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    tooltip: 'Sil (ödül iptal)',
                  ),
                  if (ready)
                    FilledButton(
                      onPressed: () => widget.onClaim(opening),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        minimumSize: const Size(0, 34),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                        ),
                      ),
                      child: Text(
                        'Ödülü Al',
                        style: AppTextStyles.dialogButton.copyWith(
                          fontSize: 12,
                        ),
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
