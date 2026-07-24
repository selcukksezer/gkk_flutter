import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/common/app_messenger.dart';
import '../../../core/services/ad_service.dart';
import '../../../core/utils/bank_tutorial.dart';
import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../providers/box_opening_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../providers/player_provider.dart';
import '../../../repositories/inventory_repository.dart';
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

  static const String _logPath =
      '/Users/selcuk/Documents/gkk-web/gkk_flutter/.cursor/debug-02eb2a.log';

  void _agentLog(String hypothesisId, String message, Map<String, Object?> data) {
    // #region agent log
    try {
      final Map<String, Object?> payload = <String, Object?>{
        'sessionId': '02eb2a',
        'runId': 'item-popup',
        'hypothesisId': hypothesisId,
        'location': 'inventory_item_detail_flow.dart',
        'message': message,
        'data': data,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      File(_logPath).writeAsStringSync(
        '${jsonEncode(payload)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {}
    // #endregion
  }

  void _showSnack(String message) {
    if (!context.mounted) return;
    AppMessenger.show(context, message);
  }

  InventoryItemDetailActions _actionsFor(BuildContext dialogContext) {
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
    );
  }

  Future<void> open(InventoryItem item) async {
    if (!context.mounted) return;

    _agentLog('H1', 'item detail open', <String, Object?>{
      'source': source,
      'itemId': item.itemId,
      'rowId': item.rowId,
      'isEquipped': item.isEquipped,
    });

    final BoxOpening? opening =
        ref.read(boxOpeningProvider.notifier).openingForRow(item.rowId);
    if (opening != null) {
      await _openLockedBoxPopup(item, opening);
      return;
    }

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
              actions: _actionsFor(dialogContext),
            ),
          ),
        );
      },
    );
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
      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          backgroundColor: const Color(0xFF141B2A),
          title: const Text(
            'Stat Sifirlama',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          content: const Text(
            'Dagitilmis stat puanlarin geri alinir.\n'
            'Saldiri, Savunma ve Sans bonuslari sifirlanir.\n\n'
            'Devam?',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Iptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sifirla'),
            ),
          ],
        ),
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
    _showSnack(result.message ?? '${item.name} kullanildi.');
  }

  Future<void> _handleBoxOpenFlow(InventoryItem item) async {
    if (ref.read(boxOpeningProvider.notifier).openingForRow(item.rowId) !=
        null) {
      _showSnack('Bu kutu zaten aciliyor.');
      return;
    }

    final String? payment = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141B2A),
        title: Text(
          '📦 ${item.name}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: const Text(
          'Kutuyu nasil acmak istersin?\n\n'
          '💎 Gem: aninda acilir\n'
          '📺 Reklam: 30 dakika sayac',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Iptal'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop('ad'),
            child: const Text('📺 Reklam Izle'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop('gems'),
            child: const Text('💎 Gem ile Ac'),
          ),
        ],
      ),
    );
    if (payment == null || !context.mounted) return;

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
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Kutuyu Sil'),
        content: const Text(
          'Kutu silinirse odul IPTAL olur — sure dolsa bile item verilmez. Emin misin?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgec'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
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
    if (!item.isTradeable) {
      _showSnack('Bu item satilamaz.');
      return;
    }

    final int? quantity = await showDialog<int>(
      context: context,
      builder: (BuildContext ctx) => InventoryQuantityActionDialog(
        title: 'Item Sat',
        subtitle: '${item.name} satmak istedigin miktari sec.',
        confirmLabel: 'Sat',
        unitValue: item.vendorSellPrice,
        maxQuantity: item.quantity,
      ),
    );

    if (quantity == null) return;
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
      builder: (BuildContext ctx) => InventoryQuantityActionDialog(
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
      final String? error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Stack bolme basarisiz.');
      return;
    }
    _showSnack('$quantity adet ${item.name} ayrildi.');
  }

  Future<void> _handleDelete(InventoryItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Item Sil'),
        content: Text(
          '${item.name} itemini cop kutusuna gondermek istiyor musun?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Iptal'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
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
