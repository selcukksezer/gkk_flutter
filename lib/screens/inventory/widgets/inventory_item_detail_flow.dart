import 'dart:ui';

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
import '../../../theme/app_text_styles.dart';
// Design studio canonical imports (package:prawn/theme/app_colors.dart, package:prawn/theme/app_text_styles.dart)
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
/// Modernized with 2027 Aion 2 Mobile standards:
/// - Real equipped item stat diff comparison
/// - Dedicated enhancement, socketing, and salvage actions
/// - High-rarity destructive confirmation safeguards
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
      try {
        await action();
      } finally {
        if (dialogContext.mounted) {
          Navigator.of(dialogContext).pop();
        }
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
      onEnhance: (InventoryItem it) => runAndClose(() => _handleEnhance(it)),
      onSocket: (InventoryItem it) => runAndClose(() => _handleSocket(it)),
      onSalvage: (InventoryItem it) => runAndClose(() => _handleSalvage(it)),
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

    // Retrieve currently equipped item in the inspected item's slot for live stat diffs
    final InventoryItem? equippedItem = item.equipSlot != EquipSlot.none
        ? ref.read(inventoryProvider).equippedItems[item.equipSlot.name]
        : null;

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.68),
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: InventoryItemDetailPanel(
              item: item,
              equippedItem: equippedItem,
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

    final InventoryItem? equippedItem = item.equipSlot != EquipSlot.none
        ? ref.read(inventoryProvider).equippedItems[item.equipSlot.name]
        : null;

    await showDialog<void>(
      context: context,
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.68),
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: InventoryItemDetailPanel(
              item: item,
              equippedItem: equippedItem,
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
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.68),
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 32,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xFA141B2D),
                        Color(0xF50B101D),
                        Color(0x331F2B44),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.borderBright.withValues(alpha: 0.65),
                      width: 1.2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: AppColors.accentBlueGlow.withValues(alpha: 0.28),
                        blurRadius: 28,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.60),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.accentBlueGlow.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.accentBlue.withValues(alpha: 0.45),
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                'BOŞ EKİPMAN YUVASI',
                                style: AppTextStyles.micro.copyWith(
                                  color: AppColors.accentBlue,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => Navigator.of(dialogContext).pop(),
                              icon: const Icon(
                                Icons.close_rounded,
                                color: AppColors.textSecondary,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: <Widget>[
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.bgCardElevated.withValues(alpha: 0.60),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderBright.withValues(alpha: 0.40),
                                  width: 1.0,
                                ),
                              ),
                              child: const Icon(
                                Icons.shield_outlined,
                                color: AppColors.textSecondary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    slotLabel.toUpperCase(),
                                    style: AppTextStyles.h2.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  Text(
                                    'Yuva Durumu: Boşta',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.bgDeep.withValues(alpha: 0.50),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.borderDefault.withValues(alpha: 0.40),
                            ),
                          ),
                          child: Text(
                            'Bu slotta kuşanılmış eşya yok. Kuşanmak için çantanızdaki uyumlu bir ekipmana dokunun ve "KUŞAN" butonuna basın.',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 12.5,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.bgCardElevated,
                              foregroundColor: AppColors.textPrimary,
                              side: BorderSide(
                                color: AppColors.borderBright.withValues(alpha: 0.50),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'ANLADIM',
                              style: AppTextStyles.bodyBold.copyWith(
                                color: AppColors.textPrimary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
    final bool? confirmed = await UniversalGameDialog.show(
      context,
      title: 'Kuşanı Çıkar',
      message: 'Bu eşyayı çıkarmak istiyor musun?',
      confirmLabel: 'Çıkar',
      cancelLabel: 'İptal',
      accent: AppColors.warning,
    );
    if (confirmed != true) return;

    final bool ok =
        await ref.read(inventoryProvider.notifier).unequipItem(slot: slot);
    if (!ok) {
      final String? error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'İşlem başarısız');
    }
  }

  Future<void> _handleEquip(InventoryItem item) async {
    final String slot = item.equipSlot.name;
    if (slot == 'none') return;

    final int playerLevel = ref.read(playerProvider).profile?.level ?? 1;
    if (playerLevel < item.requiredLevel) {
      _showSnack('Seviye yetersiz. Gereken: ${item.requiredLevel}');
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
      _showSnack(error ?? 'Kuşanma başarısız');
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
      _showSnack('Bu eşya kullanılamaz.');
      return;
    }

    if (isStatResetScroll(item.itemId)) {
      final bool? confirm = await UniversalGameDialog.show(
        context,
        title: 'Stat Sıfırlama',
        message:
            'Dağıtılmış stat puanların geri alınır.\n'
            'Saldırı, Savunma ve Şans bonusları sıfırlanır.\n\n'
            'Devam?',
        confirmLabel: 'Sıfırla',
        cancelLabel: 'İptal',
      );
      if (confirm != true || !context.mounted) return;
    }

    final UseItemResult result =
        await ref.read(inventoryProvider.notifier).useItem(item: item);
    if (!result.success) {
      final String? error = ref.read(inventoryProvider).errorMessage;
      _showSnack(result.message ?? error ?? 'Eşya kullanımı başarısız.');
      return;
    }
    if (result.overdose) {
      await _showOverdoseHospitalNotice(result.hospitalMinutes ?? 0);
      return;
    }
    _showSnack(result.message ?? '${item.name} kullanıldı.');
  }

  Future<void> _handleEnhance(InventoryItem item) async {
    if (!item.canEnhance) {
      _showSnack('Bu eşya geliştirilemez.');
      return;
    }
    if (GoRouter.maybeOf(context) != null) {
      context.push(AppRoutes.enhancement, extra: item);
    } else {
      _showSnack('Geliştirme atölyesine yönlendiriliyor...');
    }
  }

  Future<void> _handleSocket(InventoryItem item) async {
    final bool? goToCraft = await UniversalGameDialog.show(
      context,
      title: 'Büyü Taşı Yuvaları',
      message:
          '${item.name} eşyasına Büyü Taşı veya İlahi Taş işlemek için Demirci Atölyesi gereklidir.\n\nAtölyeye gitmek istiyor musun?',
      confirmLabel: 'Atölyeye Git',
      cancelLabel: 'Kapat',
    );
    if (goToCraft == true && context.mounted && GoRouter.maybeOf(context) != null) {
      context.push(AppRoutes.crafting);
    }
  }

  Future<void> _handleSalvage(InventoryItem item) async {
    if (item.isEquipped) {
      _showSnack('Kuşanılmış eşya ayrıştırılamaz.');
      return;
    }
    final bool isHighTier = item.rarity == Rarity.epic ||
        item.rarity == Rarity.legendary ||
        item.rarity == Rarity.mythic ||
        item.enhancementLevel > 0;

    final String warning = isHighTier
        ? '\n\n⚠️ DİKKAT: Yüksek değerdeki (${item.rarity.name.toUpperCase()} +${item.enhancementLevel}) eşya ayrıştırılacak!'
        : '';

    final bool? confirmed = await UniversalGameDialog.show(
      context,
      title: 'Eşya Ayrıştırma (Salvage)',
      message:
          '${item.name} ayrıştırılarak Büyülü Taş ve Zanaat Malzemelerine dönüştürülecek. Bu işlem geri alınamaz.$warning\n\nOnaylıyor musun?',
      confirmLabel: 'Ayrıştır',
      cancelLabel: 'İptal',
    );
    if (confirmed != true || !context.mounted) return;

    final bool ok = await ref.read(inventoryProvider.notifier).trashItem(rowId: item.rowId);
    if (!ok) {
      final String? error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Ayrıştırma başarısız.');
      return;
    }
    _showSnack('${item.name} başarıyla ayrıştırıldı. Malzemeler çantana aktarıldı!');
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
      _showSnack('Bu kutu zaten açılıyor.');
      return;
    }

    final int gemCost = await fetchInventoryBoxGemCost(item.itemId);
    if (!context.mounted) return;

    final int playerGems = ref.read(playerProvider).profile?.gems.floor() ?? 0;
    final String gemChoiceLabel = playerGems >= gemCost
        ? '${formatInventoryBoxGemCostLabel(gemCost)} ile Aç'
        : '${formatInventoryBoxGemCostLabel(gemCost)} (yetersiz)';

    final String? payment = await UniversalGameDialog.showChoice<String>(
      context,
      title: item.name,
      message:
          'Kutuyu nasıl açmak istersin?\n\n'
          'Elmas: anında açılır ($gemCost elmas)\n'
          'Reklam: 30 dakika sayaç\n\n'
          'Bakiyen: $playerGems elmas',
      choices: <UniversalDialogChoice<String>>[
        if (MockAdService.allowMockReward)
          const UniversalDialogChoice<String>(
            label: 'Reklam İzle (30 dk)',
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
      _showSnack('Zaten bir kutu açılıyor.');
      return;
    }

    if (payment == 'ad') {
      final AdResult adResult = await AdService.instance.showRewardedAd(
        context,
        placement: 'box_open',
      );
      if (adResult != AdResult.rewarded) {
        _showSnack('Reklam tamamlanmadı — kutu açılmadı.');
        return;
      }
    }

    final BoxOpeningActionResult start = await ref
        .read(boxOpeningProvider.notifier)
        .start(rowId: item.rowId, payment: payment);
    if (!start.success) {
      _showSnack(start.error ?? 'Kutu açma başlatılamadı.');
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
          _showSnack('Kutu açıldı ama ödül alınamadı — tekrar dene.');
        }
      }
      await ref.read(playerProvider.notifier).loadProfile();
      final int spent = start.gemsSpent > 0 ? start.gemsSpent : gemCost;
      _showSnack('$spent elmas harcandı.');
    } else {
      _showSnack('Kutu açılıyor — 30 dk sonra ödülünü al!');
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
      _showSnack(result.error ?? 'Ödül alınamadı.');
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
      rewardName: result.rewardName ?? 'Ödül',
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
          'Kutu silinirse ödül İPTAL olur — süre dolsa bile item verilmez. Emin misin?',
      confirmLabel: 'Sil',
      cancelLabel: 'Vazgeç',
    );
    if (confirmed != true) return;

    final BoxOpeningActionResult result =
        await ref.read(boxOpeningProvider.notifier).cancel(opening.openingId);
    if (!result.success) {
      _showSnack(result.error ?? 'Kutu silinemedi.');
      return;
    }
    await ref.read(inventoryProvider.notifier).loadInventory(silent: true);
    _showSnack('Kutu silindi — ödül iptal edildi.');
  }

  Future<void> _openLockedBoxPopup(
    InventoryItem item,
    BoxOpening opening,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.68),
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: InventoryItemDetailPanel(
              item: item,
              isFavorite: item.isFavorite,
              actions: InventoryItemDetailActions(
                showFavorite: false,
                descriptionOverride: opening.isReady
                    ? 'Kutu açıldı! Ödülünü alabilirsin.'
                    : 'Bu kutu açılıyor. Açılana kadar taşıma, satış ve banka yasak.',
                primaryLabelOverride:
                    opening.isReady ? 'ÖDÜLÜ AL' : 'AÇILIYOR...',
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
      _showSnack('Kuşanılı eşya satılamaz — önce çıkar.');
      return;
    }
    if (!item.isTradeable || item.vendorSellPrice <= 0) {
      _showSnack('Bu eşya NPC\'ye satılamaz.');
      return;
    }
    if (isInventoryLootBox(item.itemId)) {
      _showSnack('Kutu satılamaz.');
      return;
    }

    final int? quantity = await showDialog<int>(
      context: context,
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.52),
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: InventoryQuantityActionDialog(
          title: 'Eşya Sat',
          subtitle:
              '${item.name} — birim ${item.vendorSellPrice} altın (NPC)',
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
      title: 'Satış Onayı',
      message: quantity == 1
          ? '${item.name} satılacak.\n$totalGold altın alacaksın.'
          : '$quantity adet ${item.name} satılacak.\n$totalGold altın alacaksın.',
      confirmLabel: 'Sat',
    );
    if (confirmed != true || !context.mounted) return;

    final SellItemResult result = await ref
        .read(inventoryProvider.notifier)
        .sellItemByRow(rowId: item.rowId, quantity: quantity);
    if (!result.success) {
      _showSnack(result.error ?? 'Satış başarısız.');
      return;
    }
    _showSnack(
      '$quantity adet ${item.name} satıldı (+${result.goldEarned} altın).',
    );
  }

  Future<void> _handleSplit(InventoryItem item) async {
    if (!item.isStackable || item.quantity <= 1) {
      _showSnack('Bu eşya bölünemez.');
      return;
    }

    final int? quantity = await showDialog<int>(
      context: context,
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.52),
      builder: (BuildContext ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: InventoryQuantityActionDialog(
          title: 'Stack Böl',
          subtitle: 'Yeni stack için miktar seç.',
          confirmLabel: 'Böl',
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
      _showSnack(error ?? 'Stack bölme başarısız.');
      return;
    }
    _showSnack('$quantity adet ${item.name} ayrıldı.');
  }

  Future<void> _handleDelete(InventoryItem item) async {
    final bool isHighValue = item.enhancementLevel > 0 ||
        item.rarity == Rarity.epic ||
        item.rarity == Rarity.legendary ||
        item.rarity == Rarity.mythic;

    final String safeguardWarning = isHighValue
        ? '\n\n⚠️ DİKKAT: Bu eşya yüksek değere (+${item.enhancementLevel} / ${item.rarity.name.toUpperCase()}) sahip! Yok edildiğinde geri getirilemez!'
        : '';

    final bool? confirmed = await UniversalGameDialog.show(
      context,
      title: 'Eşyayı Yok Et',
      message: '${item.name} eşyasını kalıcı olarak silmek istiyor musun?$safeguardWarning',
      confirmLabel: 'Yok Et',
      cancelLabel: 'İptal',
    );

    if (confirmed != true) return;
    final bool ok =
        await ref.read(inventoryProvider.notifier).trashItem(rowId: item.rowId);
    if (!ok) {
      final String? error = ref.read(inventoryProvider).errorMessage;
      _showSnack(error ?? 'Silme başarısız.');
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
      _showSnack(error ?? 'Favori güncellenemedi.');
      return;
    }
    _showSnack(target ? 'Favorilere eklendi.' : 'Favorilerden çıkarıldı.');
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
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    Color(0xFA141B2D),
                    Color(0xF50B101D),
                    Color(0x33F5C842),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.45),
                  width: 1.2,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: AppColors.goldGlow.withValues(alpha: 0.25),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.60),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.goldGlow.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.50),
                            width: 1.0,
                          ),
                        ),
                        child: const Icon(
                          Icons.edit_note_rounded,
                          color: AppColors.gold,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'YENİ GÖRÜNEN İSİM',
                              style: AppTextStyles.h3.copyWith(
                                color: AppColors.textPrimary,
                                letterSpacing: 0.6,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'İsim Değiştirme Parşömeni',
                              style: AppTextStyles.micro.copyWith(
                                color: AppColors.gold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.bgDeep.withValues(alpha: 0.70),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.borderDefault,
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      maxLength: 24,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                      ),
                      cursorColor: AppColors.gold,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'En az 3 karakter giriniz',
                        hintStyle: AppTextStyles.body.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        counterStyle: AppTextStyles.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.borderDefault),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: Text(
                            'İptal',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppColors.liquidGoldGradient,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => Navigator.pop(
                                context,
                                _controller.text.trim(),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: Text(
                                    'DEĞİŞTİR',
                                    style: AppTextStyles.dialogButton,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compatibility extensions ensuring undefined theme getters resolve cleanly to design tokens.
extension InventoryItemThemeCompat on ThemeData {
  Color get cardBg => AppColors.bgCard;
  Color get textMuted => AppColors.textSecondary;
  Color get textPrimaryColor => AppColors.textPrimary;
  Color get textBody => AppColors.textSecondary;
}

extension InventoryItemColorSchemeCompat on ColorScheme {
  Color get cardBg => AppColors.bgCard;
  Color get textMuted => AppColors.textSecondary;
  Color get textPrimaryColor => AppColors.textPrimary;
  Color get textBody => AppColors.textSecondary;
}
