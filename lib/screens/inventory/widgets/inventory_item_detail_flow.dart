import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../components/common/app_messenger.dart';
import '../../../components/common/universal_game_dialog.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/tutorial/tutorial_anchor_registry.dart';
import '../../../core/tutorial/tutorial_controller.dart';
import '../../../core/tutorial/tutorial_inventory_target.dart';
import '../../../theme/app_colors.dart';
import '../../../core/utils/bank_tutorial.dart';
import '../../../core/utils/inventory_box_open_cost.dart';
import '../../../core/utils/potion_health.dart';
import '../../../core/utils/restriction_time.dart';
import '../../../l10n/l10n.dart';
import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../models/player_model.dart';
import '../../../providers/box_opening_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../repositories/inventory_repository.dart';
import '../../../routing/app_router.dart';
import 'inventory_item_detail_panel.dart';
import 'inventory_quantity_action_dialog.dart';
import 'loot_reward_dialog.dart';

/// Envanter grid popup akisi — tum ekranlardan ayni tasarim.
class InventoryItemDetailFlow {
  InventoryItemDetailFlow({
    required this.context,
    required this.ref,
    this.source = 'unknown',
    this.onEquipSuccess,
  });

  final BuildContext context;
  final WidgetRef ref;
  final String source;
  final VoidCallback? onEquipSuccess;

  void _showSnack(String message) {
    if (!context.mounted) return;
    AppMessenger.show(context, message);
  }

  InventoryItemDetailActions _actionsFor(
    BuildContext dialogContext,
    InventoryItem item,
  ) {
    Future<void> runAndClose(Future<void> Function() action) async {
      await action();
      if (dialogContext.mounted) {
        Navigator.of(dialogContext).pop();
      }
    }

    return InventoryItemDetailActions(
      onEquip: (InventoryItem it) => runAndClose(() => _handleEquip(it)),
      onUnequip: (InventoryItem it) =>
          runAndClose(() => _handleUnequip(it.equipSlot.name)),
      onUse: (InventoryItem it) => runAndClose(() => _handleUse(it)),
      onSell: (InventoryItem it) => runAndClose(() => _handleSell(it)),
      onSplit: (InventoryItem it) => runAndClose(() => _handleSplit(it)),
      onDelete: (InventoryItem it) => runAndClose(() => _handleDelete(it)),
      onToggleFavorite: (InventoryItem it) =>
          runAndClose(() => _handleToggleFavorite(it)),
      consumableEffectLabel: _consumableEffectLabel(item),
    );
  }

  String? _consumableEffectLabel(InventoryItem item) {
    final PlayerProfile? profile = ref.read(playerProvider).profile;
    final bool alchemist = profile?.characterClass == CharacterClass.alchemist;
    final int tolerance = profile?.tolerance ?? 0;
    return healthPotionEffectLabel(
      item: item,
      tolerance: tolerance,
      alchemistBonus: alchemist,
      maxHealth: profile?.maxHealth,
    );
  }

  Future<void> open(InventoryItem item) async {
    if (!context.mounted) return;

    final BoxOpening? opening =
        ref.read(boxOpeningProvider.notifier).openingForRow(item.rowId);
    if (opening != null) {
      await _openLockedBoxPopup(item, opening);
      return;
    }

    final bool canDirectUnequip =
        ref.read(inventoryProvider.notifier).canDirectUnequip();
    const String unequipBlockedReason =
        'Envanter dolu — benzer slottaki esyayla degistir';

    final int? boxGemOpenCost = isInventoryLootBox(item.itemId)
        ? await fetchInventoryBoxGemCost(item.itemId)
        : null;
    if (!context.mounted) return;

    final TutorialState tutorial = ref.read(tutorialProvider);
    final String? tutorialLootRow =
        TutorialInventoryTarget.lootEquippableRowId(ref.read(inventoryProvider));
    // Attach while opening for equip coach (after upgrade) — was inventory_equip.
    final bool attachEquipAnchor = item.rowId == tutorialLootRow &&
        (tutorial.activeStep?.id == 'enhance_equip' ||
            tutorial.activeStep?.id == 'enhance_open_item');

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
            child: InventoryItemDetailPanel(
              item: item,
              isFavorite: item.isFavorite,
              actions: _actionsFor(dialogContext, item),
              canDirectUnequip: canDirectUnequip,
              unequipBlockedReason:
                  canDirectUnequip ? null : unequipBlockedReason,
              boxGemOpenCost: boxGemOpenCost,
              attachTutorialEquipAnchor: attachEquipAnchor,
              playerLevel: ref.read(playerProvider).profile?.level,
            ),
          ),
        );
      },
    );
    if (attachEquipAnchor) {
      TutorialAnchorRegistry.instance.scheduleRefresh();
    }
  }

  /// Home / showcase — bilgi only, aksiyon yok.
  Future<void> openInfo(InventoryItem item) async {
    if (!context.mounted) return;

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
            child: InventoryItemDetailPanel(
              item: item,
              isFavorite: item.isFavorite,
              actions: const InventoryItemDetailActions(),
              infoOnly: true,
            ),
          ),
        );
      },
    );
  }

  static Future<void> showEmptyEquipSlotInfo(
    BuildContext context, {
    required String slotLabel,
  }) {
    return showDialog<void>(
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
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: InventoryItemDetailPanel.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
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
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'BOS SLOT',
                              style: TextStyle(
                                color: InventoryItemDetailPanel.textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: InventoryItemDetailPanel.textMuted,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 36,
                              minHeight: 36,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        slotLabel.toUpperCase(),
                        style: const TextStyle(
                          color: InventoryItemDetailPanel.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Bu slotta esya yok. Kusanmak icin envanter ekranini kullan.',
                        style: TextStyle(
                          color: InventoryItemDetailPanel.textBody,
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleUnequip(String slot) async {
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
    if (confirmed != true) return;

    final bool ok =
        await ref.read(inventoryProvider.notifier).unequipItem(slot: slot);
    if (!ok) {
      final String? error = ref.read(inventoryProvider).errorMessage;
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
      final String? error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Kusanma basarisiz');
      return;
    }

    onEquipSuccess?.call();
  }

  Future<void> _handleUse(InventoryItem item) async {
    if (isInventoryLootBox(item.itemId)) {
      await _handleBoxOpenFlow(item);
      return;
    }

    if (isNameChangeScroll(item.itemId)) {
      await _handleNameChangeFlow(item);
      return;
    }

    final bool canUse =
        isStatResetScroll(item.itemId) ||
        item.itemType == ItemType.potion ||
        item.itemType == ItemType.consumable ||
        item.potionType != PotionType.none ||
        item.energyRestore > 0 ||
        item.healthRestore > 0;
    if (!canUse) {
      _showSnack('Bu item kullanilamaz.');
      return;
    }

    if (isStatResetScroll(item.itemId)) {
      final bool? confirm = await UniversalGameDialog.show(
        context,
        title: 'Stat Sifirlama',
        message:
            'Dagitilmis stat puanlarin geri alinir.\n'
            'Saldiri, Savunma ve Sans bonuslari sifirlanir.\n\n'
            'Devam?',
        confirmLabel: 'Sifirla',
        cancelLabel: 'Iptal',
      );
      if (confirm != true || !context.mounted) return;
    }

    final UseItemResult result =
        await ref.read(inventoryProvider.notifier).useItem(item: item);
    if (!result.success) {
      final String? error = ref.read(inventoryProvider).errorMessage;
      _showSnack(result.message ?? error ?? 'Item kullanimi basarisiz.');
      return;
    }
    if (result.overdose) {
      await _showOverdoseHospitalNotice(result.hospitalMinutes ?? 0);
      return;
    }
    _showSnack(result.message ?? '${item.name} kullanildi.');
  }

  Future<void> _showOverdoseHospitalNotice(int hospitalMinutes) async {
    if (!context.mounted) return;
    final bool english = Localizations.localeOf(context).languageCode == 'en';
    final String duration = formatHospitalDurationMinutes(
      hospitalMinutes,
      english: english,
    );
    final String message = context.l10n.overdose_hospitalized(duration);
    await UniversalGameDialog.showInfo(
      context,
      title: context.l10n.overdose_hospitalized_title,
      message: message,
      confirmLabel: context.l10n.hastaneye_git,
    );
    if (!context.mounted) return;
    _showSnack(message);
    if (GoRouter.maybeOf(context) != null) {
      context.go(AppRoutes.hospital);
    }
  }

  Future<void> _handleNameChangeFlow(InventoryItem item) async {
    final String current = ref.read(playerProvider).profile?.displayName ??
        ref.read(playerProvider).profile?.username ??
        '';
    final String? newName = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => _NameChangeScrollDialog(initialName: current),
    );

    if (newName == null || newName.length < 3) {
      if (newName != null && newName.isNotEmpty) {
        _showSnack('İsim en az 3 karakter olmalı.');
      }
      return;
    }

    if (!context.mounted) return;

    final bool? confirm = await UniversalGameDialog.show(
      context,
      title: 'İsim Değiştirme Kağıdı',
      message: 'Görünen ismin "$newName" olacak.\nKağıt tüketilir.\n\nDevam?',
      confirmLabel: 'Değiştir',
      cancelLabel: 'İptal',
    );
    if (confirm != true || !context.mounted) return;

    final UseItemResult result = await ref
        .read(inventoryProvider.notifier)
        .useNameChangeScroll(item: item, newDisplayName: newName);
    if (!result.success) {
      _showSnack(result.message ?? 'İsim değiştirilemedi.');
      return;
    }
    _showSnack(result.message ?? 'Görünen isim güncellendi.');
  }

  Future<void> _handleBoxOpenFlow(InventoryItem item) async {
    if (ref.read(boxOpeningProvider.notifier).openingForRow(item.rowId) !=
        null) {
      _showSnack('Bu kutu zaten aciliyor.');
      return;
    }

    final int gemCost = await fetchInventoryBoxGemCost(item.itemId);
    if (!context.mounted) return;

    final int playerGems = ref.read(playerProvider).profile?.gems.floor() ?? 0;
    final String gemChoiceLabel = playerGems >= gemCost
        ? '${formatInventoryBoxGemCostLabel(gemCost)} ile Ac'
        : '${formatInventoryBoxGemCostLabel(gemCost)} (yetersiz)';

    final String? payment = await UniversalGameDialog.showChoice<String>(
      context,
      title: item.name,
      message:
          'Kutuyu nasil acmak istersin?\n\n'
          'Elmas: aninda acilir ($gemCost elmas)\n'
          'Reklam: 30 dakika sayac\n\n'
          'Bakiyen: $playerGems elmas',
      choices: <UniversalDialogChoice<String>>[
        if (MockAdService.allowMockReward)
          const UniversalDialogChoice<String>(
            label: 'Reklam Izle (30 dk)',
            value: 'ad',
            isPrimary: false,
          ),
        UniversalDialogChoice<String>(
          label: gemChoiceLabel,
          value: 'gems',
        ),
      ],
    );
    if (payment == null || !context.mounted) return;

    if (payment == 'gems' && playerGems < gemCost) {
      _showSnack('Yetersiz elmas — $gemCost elmas gerekli.');
      return;
    }

    if (ref.read(boxOpeningProvider).isNotEmpty) {
      _showSnack('Zaten bir kutu aciliyor.');
      return;
    }

    if (payment == 'ad') {
      final AdResult adResult = await AdService.instance.showRewardedAd(
        context,
        placement: 'box_open',
      );
      if (adResult != AdResult.rewarded) {
        _showSnack('Reklam tamamlanmadi — kutu acilmadi.');
        return;
      }
    }

    final BoxOpeningActionResult start = await ref
        .read(boxOpeningProvider.notifier)
        .start(rowId: item.rowId, payment: payment);
    if (!start.success) {
      _showSnack(start.error ?? 'Kutu acma baslatilamadi.');
      return;
    }

    if (payment == 'gems') {
      final String? openingId = start.openingId;
      if (openingId != null && openingId.isNotEmpty) {
        await _handleBoxClaimById(
          openingId: openingId,
          boxName: item.name,
        );
      } else {
        final BoxOpening? opening =
            ref.read(boxOpeningProvider.notifier).openingForRow(item.rowId);
        if (opening != null) {
          await _handleBoxClaim(opening);
        } else {
          _showSnack('Kutu acildi ama odul alinamadi — tekrar dene.');
        }
      }
      await ref.read(playerProvider.notifier).loadProfile();
      final int spent = start.gemsSpent > 0 ? start.gemsSpent : gemCost;
      _showSnack('$spent elmas harcandi.');
    } else {
      _showSnack('Kutu aciliyor — 30 dk sonra odulunu al!');
    }
  }

  Future<void> claimOpening(BoxOpening opening) => _handleBoxClaim(opening);

  Future<void> cancelOpening(BoxOpening opening) => _handleBoxCancel(opening);

  Future<void> _handleBoxClaimById({
    required String openingId,
    required String boxName,
  }) async {
    final BoxOpeningActionResult result =
        await ref.read(boxOpeningProvider.notifier).claim(openingId);
    if (!result.success) {
      _showSnack(result.error ?? 'Odul alinamadi.');
      if (context.mounted &&
          (result.error ?? '').toLowerCase().contains('envanter dolu')) {
        await BankTutorial.maybeShowInventoryFullDialog(context, ref);
      }
      return;
    }
    await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
    if (!context.mounted) return;
    await showLootRewardDialog(
      context,
      title: boxName,
      rewardName: result.rewardName ?? 'Odul',
      rewardQuantity: result.rewardQuantity,
    );
  }

  Future<void> _handleBoxClaim(BoxOpening opening) async {
    await _handleBoxClaimById(
      openingId: opening.openingId,
      boxName: opening.boxName,
    );
  }

  Future<void> _handleBoxCancel(BoxOpening opening) async {
    final bool? confirmed = await UniversalGameDialog.show(
      context,
      title: 'Kutuyu Sil',
      message:
          'Kutu silinirse odul IPTAL olur — sure dolsa bile item verilmez. Emin misin?',
      confirmLabel: 'Sil',
      cancelLabel: 'Vazgec',
    );
    if (confirmed != true) return;

    final BoxOpeningActionResult result =
        await ref.read(boxOpeningProvider.notifier).cancel(opening.openingId);
    if (!result.success) {
      _showSnack(result.error ?? 'Kutu silinemedi.');
      return;
    }
    await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
    _showSnack('Kutu silindi — odul iptal edildi.');
  }

  Future<void> _openLockedBoxPopup(
    InventoryItem item,
    BoxOpening opening,
  ) async {
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
            child: InventoryItemDetailPanel(
              item: item,
              isFavorite: item.isFavorite,
              actions: InventoryItemDetailActions(
                showFavorite: false,
                descriptionOverride: opening.isReady
                    ? 'Kutu acildi! Odulunu alabilirsin.'
                    : 'Bu kutu aciliyor. Acilana kadar tasima, satis ve banka yasak.',
                primaryLabelOverride:
                    opening.isReady ? 'ODULU AL' : 'ACILIYOR...',
                onPrimaryOverride: opening.isReady
                    ? (InventoryItem _) async {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                        await _handleBoxClaim(opening);
                      }
                    : null,
                onDelete: (InventoryItem _) async {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  await _handleBoxCancel(opening);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSell(InventoryItem item) async {
    if (item.isEquipped) {
      _showSnack('Kusanili esya satilamaz — once cikar.');
      return;
    }
    if (!item.isTradeable || item.vendorSellPrice <= 0) {
      _showSnack('Bu item NPC\'ye satilamaz.');
      return;
    }
    if (isInventoryLootBox(item.itemId)) {
      _showSnack('Kutu satilamaz.');
      return;
    }

    final int? quantity = await showDialog<int>(
      context: context,
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.52),
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: InventoryQuantityActionDialog(
          title: 'Esya Sat',
          subtitle:
              '${item.name} — birim ${item.vendorSellPrice} altin (NPC)',
          confirmLabel: 'Sat',
          unitValue: item.vendorSellPrice,
          maxQuantity: item.quantity,
        ),
      ),
    );

    if (quantity == null || !context.mounted) return;

    final int totalGold = item.vendorSellPrice * quantity;
    final bool? confirmed = await UniversalGameDialog.show(
      context,
      title: 'Satis Onayi',
      message: quantity == 1
          ? '${item.name} satilacak.\n$totalGold altin alacaksin.'
          : '$quantity adet ${item.name} satilacak.\n$totalGold altin alacaksin.',
      confirmLabel: 'Sat',
    );
    if (confirmed != true || !context.mounted) return;

    final SellItemResult result = await ref
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
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.52),
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: InventoryQuantityActionDialog(
          title: 'Stack Bol',
          subtitle: 'Yeni stack icin miktar sec.',
          confirmLabel: 'Bol',
          unitValue: 0,
          maxQuantity: item.quantity - 1,
          showTotalValue: false,
        ),
      ),
    );

    if (quantity == null) return;
    final bool ok = await ref
        .read(inventoryProvider.notifier)
        .splitStack(rowId: item.rowId, splitQuantity: quantity);
    if (!ok) {
      final String? error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Stack bolme basarisiz.');
      return;
    }
    _showSnack('$quantity adet ${item.name} ayrildi.');
  }

  Future<void> _handleDelete(InventoryItem item) async {
    final bool? confirmed = await UniversalGameDialog.show(
      context,
      title: 'Item Sil',
      message: '${item.name} itemini cop kutusuna gondermek istiyor musun?',
      confirmLabel: 'Sil',
      cancelLabel: 'Iptal',
    );

    if (confirmed != true) return;
    final bool ok =
        await ref.read(inventoryProvider.notifier).trashItem(rowId: item.rowId);
    if (!ok) {
      final String? error = ref.read(inventoryProvider).errorMessage;
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
      final String? error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Favori guncellenemedi.');
      return;
    }
    _showSnack(target ? 'Favorilere eklendi.' : 'Favorilerden cikarildi.');
  }
}

class _NameChangeScrollDialog extends StatefulWidget {
  const _NameChangeScrollDialog({required this.initialName});

  final String initialName;

  @override
  State<_NameChangeScrollDialog> createState() => _NameChangeScrollDialogState();
}

class _NameChangeScrollDialogState extends State<_NameChangeScrollDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      title: const Text('Yeni görünen isim'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 24,
        decoration: const InputDecoration(
          hintText: 'En az 3 karakter',
          counterText: '',
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Değiştir'),
        ),
      ],
    );
  }
}
