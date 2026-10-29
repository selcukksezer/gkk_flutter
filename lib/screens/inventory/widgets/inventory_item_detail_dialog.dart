import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/utils/enhancement_stats.dart';
import '../../../core/utils/gold_format.dart';
import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../repositories/inventory_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';
import 'aion_rarity_glow.dart';
import 'inventory_item_detail_panel.dart';

/// Opens the 2027 Aion 2 Glassmorphic Item Detail Modal Dialog with luxury AAA presentation.
Future<void> showInventoryItemDetailDialog(
  BuildContext context, {
  required InventoryItem item,
  InventoryItemDetailActions actions = const InventoryItemDetailActions(),
  bool isFavorite = false,
  bool? isLocked,
  InventoryItem? equippedItem,
  bool infoOnly = false,
  bool canDirectUnequip = true,
  String? unequipBlockedReason,
  int? boxGemOpenCost,
  bool attachTutorialEquipAnchor = false,
  int? playerLevel,
  Future<void> Function(InventoryItem item)? onEquip,
  Future<void> Function(InventoryItem item)? onEnhance,
  Future<void> Function(InventoryItem item)? onDiscard,
  Future<void> Function(InventoryItem item)? onLock,
  Future<void> Function(InventoryItem item)? onUse,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Eşya İnceleme',
    barrierColor: AppColors.bgDeep.withValues(alpha: 0.75),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> anim,
      Animation<double> secondaryAnim,
    ) {
      return InventoryItemDetailDialog(
        item: item,
        actions: actions,
        isFavorite: isFavorite,
        isLocked: isLocked,
        equippedItem: equippedItem,
        infoOnly: infoOnly,
        canDirectUnequip: canDirectUnequip,
        unequipBlockedReason: unequipBlockedReason,
        boxGemOpenCost: boxGemOpenCost,
        attachTutorialEquipAnchor: attachTutorialEquipAnchor,
        playerLevel: playerLevel,
        onEquip: onEquip,
        onEnhance: onEnhance,
        onDiscard: onDiscard,
        onLock: onLock,
        onUse: onUse,
      );
    },
    transitionBuilder: (
      BuildContext context,
      Animation<double> anim,
      Animation<double> secondaryAnim,
      Widget child,
    ) {
      final Animation<double> curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// AAA Item Detail Modal Dialog designed with authentic mobile ergonomics & dark fantasy aesthetics.
/// Features:
/// - Prominent tactical action buttons: Equip, Enhance, Discard, Lock
/// - Live stat diff comparison chips (+/- delta indicators against equipped gear)
/// - Multi-layered rarity glow with rotating arcane runes and specular particles
/// - Durability gauge and socketed manastones & Godstone display
/// - Full compliance with AppColors, AppTextStyles, AppSpacing (zero undefined theme getters)
class InventoryItemDetailDialog extends StatefulWidget {
  const InventoryItemDetailDialog({
    super.key,
    required this.item,
    this.actions = const InventoryItemDetailActions(),
    this.isFavorite = false,
    this.isLocked,
    this.equippedItem,
    this.infoOnly = false,
    this.canDirectUnequip = true,
    this.unequipBlockedReason,
    this.boxGemOpenCost,
    this.attachTutorialEquipAnchor = false,
    this.playerLevel,
    this.onEquip,
    this.onEnhance,
    this.onDiscard,
    this.onLock,
    this.onUse,
  });

  final InventoryItem item;
  final InventoryItemDetailActions actions;
  final bool isFavorite;
  final bool? isLocked;
  final InventoryItem? equippedItem;
  final bool infoOnly;
  final bool canDirectUnequip;
  final String? unequipBlockedReason;
  final int? boxGemOpenCost;
  final bool attachTutorialEquipAnchor;
  final int? playerLevel;

  // Direct convenience callbacks for quick modal invocation
  final Future<void> Function(InventoryItem item)? onEquip;
  final Future<void> Function(InventoryItem item)? onEnhance;
  final Future<void> Function(InventoryItem item)? onDiscard;
  final Future<void> Function(InventoryItem item)? onLock;
  final Future<void> Function(InventoryItem item)? onUse;

  @override
  State<InventoryItemDetailDialog> createState() =>
      _InventoryItemDetailDialogState();
}

class _InventoryItemDetailDialogState extends State<InventoryItemDetailDialog>
    with TickerProviderStateMixin {
  late final AnimationController _runeController;
  late final AnimationController _pulseController;
  late bool _locked;

  @override
  void initState() {
    super.initState();
    _locked = widget.isLocked ?? widget.isFavorite;

    _runeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant InventoryItemDetailDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLocked != oldWidget.isLocked ||
        widget.isFavorite != oldWidget.isFavorite) {
      _locked = widget.isLocked ?? widget.isFavorite;
    }
  }

  @override
  void dispose() {
    _runeController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  AionRarityTier get _tier => AionRarityTier.fromRarity(
        widget.item.rarity,
        enhancementLevel: widget.item.enhancementLevel,
        itemId: widget.item.itemId,
      );

  int? _calculateDiff(int inspectedValue, int? equippedValue) {
    if (widget.item.isEquipped) return null;
    if (widget.item.equipSlot == EquipSlot.none) return null;
    final int baseComp = equippedValue ?? 0;
    return inspectedValue - baseComp;
  }

  Future<void> _handleToggleLock() async {
    await AionHaptics.slotSelect();
    setState(() {
      _locked = !_locked;
    });

    if (widget.onLock != null) {
      await widget.onLock!(widget.item);
    } else if (widget.actions.onToggleFavorite != null) {
      await widget.actions.onToggleFavorite!(widget.item);
    }
  }

  Future<void> _handleDiscard() async {
    final InventoryItem item = widget.item;

    if (_locked) {
      await AionHaptics.error();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Kilitli eşyalar silinemez veya çöpe atılamaz. Önce kilidi açın.',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    final bool isHighValue = _tier.index >= AionRarityTier.rare.index ||
        item.enhancementLevel > 0;

    if (isHighValue) {
      await AionHaptics.buttonTap();
      if (!mounted) return;
      final bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext ctx) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: AppColors.bgSurface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.danger,
                        size: 38,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'EŞYAYI ÇÖPE AT / SİL',
                        style: AppTextStyles.dialogTitle.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${item.name.toUpperCase()} kalıcı olarak yok edilecek.\nBu işlem geri alınamaz!',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.dialogBody.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.borderBright,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Vazgeç',
                                style: AppTextStyles.dialogButtonMuted,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Yok Et',
                                style: AppTextStyles.dialogButton.copyWith(
                                  color: AppColors.textPrimary,
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
          );
        },
      );

      if (confirmed != true) return;
    }

    if (widget.onDiscard != null) {
      await widget.onDiscard!(item);
    } else if (widget.actions.onDelete != null) {
      await widget.actions.onDelete!(item);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildDurabilityBar() {
    const int currentDurability = 100;
    const int maxDurability = 100;
    const double ratio = currentDurability / maxDurability;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: AppColors.borderFaint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.shield_outlined,
                    size: 12,
                    color: AppColors.mutedTitanium,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'DAYANIKLILIK',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.mutedTitanium,
                    ),
                  ),
                ],
              ),
              Text(
                '$currentDurability / $maxDurability',
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXs / 2),
            child: SizedBox(
              height: 4,
              child: LinearProgressIndicator(
                value: ratio,
                backgroundColor: AppColors.borderFaint,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ratio > 0.5
                      ? AppColors.success
                      : (ratio > 0.2 ? AppColors.warning : AppColors.danger),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocketsSection() {
    final AionRarityTier tier = _tier;
    final int socketCount = switch (tier) {
      AionRarityTier.archon => 5,
      AionRarityTier.mythic => 4,
      AionRarityTier.epic => 3,
      AionRarityTier.rare => 2,
      AionRarityTier.common => 1,
    };

    final bool isWeapon = widget.item.itemType == ItemType.weapon;
    final bool hasGodstone =
        (tier == AionRarityTier.archon || tier == AionRarityTier.mythic) &&
            isWeapon;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm + 1),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.borderFaint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.diamond_outlined,
                    size: 13,
                    color: tier.primaryColor,
                  ),
                  const SizedBox(width: AppSpacing.xs + 1),
                  Text(
                    'BÜYÜ TAŞI YUVALARI (${widget.item.isEquipped ? 'AKTİF' : 'BOŞ'})',
                    style: AppTextStyles.micro.copyWith(
                      color: tier.primaryColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Text(
                '$socketCount Yuva',
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.mutedTitanium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs + 2),
          Column(
            children: List<Widget>.generate(socketCount, (int index) {
              final bool isGodstoneSlot = hasGodstone && index == 0;
              if (isGodstoneSlot) {
                return Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.warningSolar.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                    border: Border.all(
                      color: AppColors.warningSolar.withValues(alpha: 0.50),
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.auto_awesome,
                        size: 12,
                        color: AppColors.warningSolar,
                      ),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Expanded(
                        child: Text(
                          'İlahî Taş: Nezekan\'ın Gazabı (%5 İhtimalle 380 Kutsal Hasar)',
                          style: AppTextStyles.micro.copyWith(
                            color: AppColors.goldLight,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              final bool isFilled = index == 0 ||
                  (index == 1 && tier.index >= AionRarityTier.epic.index);
              final String socketText = isFilled
                  ? (index == 0
                      ? '✦ Kritik Vuruş +17'
                      : '✦ Fiziksel Saldırı +5')
                  : '◇ Boş Büyü Taşı Yuvası';

              return Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isFilled
                      ? AppColors.bgCardElevated.withValues(alpha: 0.60)
                      : AppColors.bgSurface.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                  border: Border.all(
                    color: isFilled
                        ? tier.primaryColor.withValues(alpha: 0.40)
                        : AppColors.borderFaint,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      isFilled ? Icons.lens : Icons.radio_button_unchecked,
                      size: 9,
                      color: isFilled
                          ? tier.primaryColor
                          : AppColors.textTertiary,
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      socketText,
                      style: AppTextStyles.micro.copyWith(
                        color: isFilled
                            ? AppColors.textPrimary
                            : AppColors.textTertiary,
                        fontWeight: isFilled ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final InventoryItem item = widget.item;
    final InventoryItem? equipped = widget.equippedItem;
    final int enh = item.enhancementLevel;
    final AionRarityTier tier = _tier;

    // Stat Diff Calculations
    final int enhItemAttack = enhancedStat(item.attack, enh);
    final int enhItemDefense = enhancedStat(item.defense, enh);
    final int enhItemHealth = enhancedStat(item.health, enh);
    final int enhItemLuck = enhancedStat(item.luck, enh);
    final int enhItemPower = enhancedItemPowerContribution(item);

    final int? enhEquippedAttack = equipped != null
        ? enhancedStat(equipped.attack, equipped.enhancementLevel)
        : null;
    final int? enhEquippedDefense = equipped != null
        ? enhancedStat(equipped.defense, equipped.enhancementLevel)
        : null;
    final int? enhEquippedHealth = equipped != null
        ? enhancedStat(equipped.health, equipped.enhancementLevel)
        : null;
    final int? enhEquippedLuck = equipped != null
        ? enhancedStat(equipped.luck, equipped.enhancementLevel)
        : null;
    final int? enhEquippedPower =
        equipped != null ? enhancedItemPowerContribution(equipped) : null;

    final List<(String, String, Color?, int?)> statList = <(String, String, Color?, int?)>[
      if (item.attack > 0 || (equipped?.attack ?? 0) > 0)
        (
          'SALDIRI',
          formatEnhancedStat(item.attack, enh),
          AppColors.danger,
          _calculateDiff(enhItemAttack, enhEquippedAttack),
        ),
      if (item.defense > 0 || (equipped?.defense ?? 0) > 0)
        (
          'SAVUNMA',
          formatEnhancedStat(item.defense, enh),
          AppColors.accentBlue,
          _calculateDiff(enhItemDefense, enhEquippedDefense),
        ),
      if (item.health > 0 || (equipped?.health ?? 0) > 0)
        (
          'CAN',
          formatEnhancedStat(item.health, enh),
          AppColors.success,
          _calculateDiff(enhItemHealth, enhEquippedHealth),
        ),
      if (item.luck > 0 || (equipped?.luck ?? 0) > 0)
        (
          'ŞANS',
          formatEnhancedStat(item.luck, enh),
          AppColors.warning,
          _calculateDiff(enhItemLuck, enhEquippedLuck),
        ),
      (
        'GÜÇ',
        '$enhItemPower',
        AppColors.liquidGold,
        _calculateDiff(enhItemPower, enhEquippedPower),
      ),
      if (enh > 0) ('YÜKSELTME', '+$enh', AppColors.warningSolar, null),
      ('SEVİYE', 'Lv. ${item.requiredLevel}', null, null),
      (
        'DEĞER',
        item.vendorSellPrice > 0
            ? '${formatCompactGold(item.vendorSellPrice)}g'
            : '—',
        AppColors.goldLight,
        null,
      ),
      if (widget.actions.consumableEffectLabel != null)
        (
          'ETKİ',
          widget.actions.consumableEffectLabel!,
          AppColors.accentTeal,
          null,
        ),
    ];

    final String description =
        widget.actions.descriptionOverride ?? item.description;

    // Equip / Action Resolutions
    final bool canEquip = item.equipSlot != EquipSlot.none;
    final bool levelOk = widget.playerLevel == null ||
        widget.playerLevel! >= item.requiredLevel;
    final bool canUse = isStatResetScroll(item.itemId) ||
        isNameChangeScroll(item.itemId) ||
        item.itemType == ItemType.potion ||
        item.itemType == ItemType.consumable ||
        item.potionType != PotionType.none ||
        item.energyRestore > 0 ||
        item.healthRestore > 0;
    final bool canSell = !item.isEquipped &&
        item.vendorSellPrice > 0 &&
        item.isTradeable &&
        widget.actions.onSell != null;
    final String sellLabel = canSell
        ? 'SAT (${formatCompactGold(item.vendorSellPrice)})'
        : 'SAT';
    final bool canSplit = item.isStackable &&
        item.quantity > 1 &&
        widget.actions.onSplit != null;

    final String primaryLabel;
    final VoidCallback? primaryAction;
    IconData? primaryIcon;

    if (widget.actions.primaryLabelOverride != null) {
      primaryLabel = widget.actions.primaryLabelOverride!;
      final Future<void> Function(InventoryItem item)? onPrimary =
          widget.actions.onPrimaryOverride;
      primaryAction = onPrimary != null
          ? () async {
              await onPrimary(item);
              if (mounted) Navigator.of(context).pop();
            }
          : null;
      primaryIcon = Icons.touch_app_rounded;
    } else if (item.isEquipped &&
        (widget.actions.onUnequip != null || widget.onEquip != null)) {
      if (widget.canDirectUnequip) {
        primaryLabel = 'ÇIKAR (${item.equipSlot.name.toUpperCase()})';
        final Future<void> Function(InventoryItem item)? onUnequip =
            widget.actions.onUnequip;
        primaryAction = () async {
          await AionHaptics.equipSuccess();
          if (onUnequip != null) {
            await onUnequip(item);
          } else if (widget.onEquip != null) {
            await widget.onEquip!(item);
          }
          if (mounted) Navigator.of(context).pop();
        };
        primaryIcon = Icons.vertical_align_bottom_rounded;
      } else {
        primaryLabel = 'ÇIKAR (ENVANTER DOLU)';
        primaryAction = null;
        primaryIcon = Icons.lock_outline_rounded;
      }
    } else if (isInventoryLootBox(item.itemId) &&
        (widget.actions.onUse != null || widget.onUse != null)) {
      final int? gemCost = widget.boxGemOpenCost;
      primaryLabel = gemCost != null
          ? 'AÇ ($gemCost ELMAS / REKLAM)'
          : 'AÇ (ELMAS / REKLAM)';
      final Future<void> Function(InventoryItem item)? onUse =
          widget.onUse ?? widget.actions.onUse;
      primaryAction = onUse != null
          ? () async {
              await AionHaptics.buttonTap();
              await onUse(item);
              if (mounted) Navigator.of(context).pop();
            }
          : null;
      primaryIcon = Icons.card_giftcard_rounded;
    } else if (canUse &&
        (widget.actions.onUse != null || widget.onUse != null)) {
      primaryLabel = 'KULLAN';
      final Future<void> Function(InventoryItem item)? onUse =
          widget.onUse ?? widget.actions.onUse;
      primaryAction = onUse != null
          ? () async {
              await AionHaptics.buttonTap();
              await onUse(item);
              if (mounted) Navigator.of(context).pop();
            }
          : null;
      primaryIcon = Icons.auto_fix_high_rounded;
    } else if (canEquip &&
        (widget.actions.onEquip != null || widget.onEquip != null)) {
      if (!levelOk) {
        primaryLabel = 'SEVİYE YETERSİZ (Lv.${item.requiredLevel})';
        primaryAction = null;
        primaryIcon = Icons.lock_outline_rounded;
      } else {
        primaryLabel = 'KUŞAN (${item.equipSlot.name.toUpperCase()})';
        final Future<void> Function(InventoryItem item)? onEquip =
            widget.onEquip ?? widget.actions.onEquip;
        primaryAction = onEquip != null
            ? () async {
                await AionHaptics.equipSuccess();
                await onEquip(item);
                if (mounted) Navigator.of(context).pop();
              }
            : null;
        primaryIcon = Icons.shield_rounded;
      }
    } else {
      primaryLabel = 'KULLANILAMAZ';
      primaryAction = null;
    }

    Widget primaryButton = InventoryDialogActionButton(
      label: primaryLabel,
      onPressed: primaryAction,
      isPrimary: true,
      icon: primaryIcon,
      accentColor: tier.primaryColor,
      secondaryColor: tier.secondaryColor,
    );

    if (primaryLabel.startsWith('KUŞAN') &&
        widget.attachTutorialEquipAnchor) {
      primaryButton = TutorialAnchorScope(
        id: TutorialAnchorId.inventoryEquipBtn,
        onTutorialTap: primaryAction == null
            ? null
            : () async {
                primaryAction?.call();
              },
        child: primaryButton,
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.xl,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AionRarityGlowBorder(
              tier: tier,
              borderRadius: AppSpacing.radiusXxl,
              borderWidth: 1.5,
              child: Container(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.md,
                  AppSpacing.base,
                  AppSpacing.base,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      AppColors.bgDeep.withValues(alpha: 0.96),
                      AppColors.bgBase.withValues(alpha: 0.94),
                      tier.primaryColor.withValues(alpha: 0.10),
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // ── Header Bar: Lock/Favorite toggle, Rarity pill, Equipped Tag & Close Button ──
                      Row(
                        children: <Widget>[
                          // Lock / Favorite Action Button
                          IconButton(
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                _locked
                                    ? Icons.lock_rounded
                                    : Icons.lock_open_rounded,
                                key: ValueKey<bool>(_locked),
                                color: _locked
                                    ? AppColors.gold
                                    : AppColors.textTertiary,
                                size: 20,
                              ),
                            ),
                            tooltip: _locked
                                ? 'Kilitli (Korunuyor)'
                                : 'Kilidi Açık',
                            onPressed: _handleToggleLock,
                          ),
                          const Spacer(),
                          // Rarity Tier Pill Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: tier.primaryColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusFull,
                              ),
                              border: Border.all(
                                color: tier.primaryColor.withValues(alpha: 0.55),
                              ),
                            ),
                            child: Text(
                              tier.displayName,
                              style: AppTextStyles.micro.copyWith(
                                color: tier.primaryColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (item.isEquipped) ...<Widget>[
                            const SizedBox(width: AppSpacing.xs + 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.20),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                                border: Border.all(
                                  color: AppColors.success.withValues(alpha: 0.50),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  const Icon(
                                    Icons.check_circle,
                                    size: 10,
                                    color: AppColors.success,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'KUŞANILDI',
                                    style: AppTextStyles.micro.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Close Button
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: AppColors.textSecondary,
                              size: 22,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Kapat',
                          ),
                        ],
                      ),

                      // ── Animated Canvas Runic Showcase & 3D Icon ──────────────
                      Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: <Widget>[
                            // Breathing Radial Rarity Glow Aura
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (BuildContext ctx, Widget? child) {
                                final double pulseScale =
                                    1.0 + (_pulseController.value * 0.10);
                                return Transform.scale(
                                  scale: pulseScale,
                                  child: Container(
                                    width: 124,
                                    height: 124,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: <Color>[
                                          tier.glowColor,
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Rotating Arcane Runes Painter
                            AnimatedBuilder(
                              animation: _runeController,
                              builder: (BuildContext ctx, Widget? child) {
                                return Transform.rotate(
                                  angle: _runeController.value * 2 * math.pi,
                                  child: CustomPaint(
                                    size: const Size(116, 116),
                                    painter: _ArcaneRuneCirclePainter(
                                      primaryColor: tier.primaryColor,
                                      secondaryColor: tier.secondaryColor,
                                    ),
                                  ),
                                );
                              },
                            ),
                            // Enchanting Particle Sparkles Overlay
                            SizedBox(
                              width: 126,
                              height: 126,
                              child: EnchantingSparklesOverlay(
                                tier: tier,
                                particleCount:
                                    tier.index >= AionRarityTier.epic.index
                                        ? 14
                                        : 7,
                              ),
                            ),
                            // Floating 3D/Item Icon View
                            ItemIconView(
                              iconValue: item.icon,
                              itemId: item.itemId,
                              itemType: item.itemType,
                              size: 80,
                              expand: true,
                            ),
                            // Radiant Enhancement Badge (+15)
                            if (enh > 0)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.sm,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: <Color>[
                                        Color(0xFF2A1B05),
                                        Color(0xFF0F0A02),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.radiusSm,
                                    ),
                                    border: Border.all(
                                      color: AppColors.liquidGold,
                                      width: 1.2,
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: AppColors.liquidGold.withValues(
                                          alpha: 0.40,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '+$enh',
                                    style: AppTextStyles.micro.copyWith(
                                      color: AppColors.liquidGold,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.sm),

                      // ── Item Name & Enhancement Badge ─────────────────────────
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Flexible(
                              child: Text(
                                item.name.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: AppTextStyles.dialogTitle.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  shadows: <Shadow>[
                                    Shadow(
                                      color: tier.primaryColor.withValues(
                                        alpha: 0.70,
                                      ),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (enh > 0) ...<Widget>[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.bgDeep.withValues(
                                    alpha: 0.90,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusXs,
                                  ),
                                  border: Border.all(
                                    color: AppColors.warningSolar.withValues(
                                      alpha: 0.75,
                                    ),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  '+$enh',
                                  style: AppTextStyles.micro.copyWith(
                                    color: AppColors.warningSolar,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xs),

                      // Slot / Type subtitle
                      Center(
                        child: Text(
                          '${item.equipSlot != EquipSlot.none ? item.equipSlot.name.toUpperCase() : item.itemType.name.toUpperCase()} · ADET: ${item.quantity}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.mutedTitanium,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // ── Bento Stats Grid with Live Diff Indicators ───────────
                      if (statList.isNotEmpty) ...<Widget>[
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: statList.map((stat) {
                            return InventoryStatDiffChip(
                              label: stat.$1,
                              value: stat.$2,
                              highlightColor: stat.$3,
                              diff: stat.$4,
                            );
                          }).toList(growable: false),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],

                      // ── Durability Bar (for gear) ─────────────────────────────
                      if (canEquip) _buildDurabilityBar(),

                      // ── Sockets & Godstone Section ────────────────────────────
                      if (canEquip) _buildSocketsSection(),

                      // ── Dark Fantasy Lore Description Box ─────────────────────
                      if (description.isNotEmpty) ...<Widget>[
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.bgSurface.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                            border: Border.all(color: AppColors.borderFaint),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                '"$description"',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs + 2),
                              Row(
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.xs + 2,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.borderFaint,
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusXs / 2,
                                      ),
                                    ),
                                    child: Text(
                                      item.isTradeable
                                          ? 'TAKAS EDİLEBİLİR'
                                          : 'KUŞANILDIĞINDA BAĞLANIR',
                                      style: AppTextStyles.micro.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (item.vendorSellPrice > 0)
                                    Text(
                                      'Satış: ${formatCompactGold(item.vendorSellPrice)}g',
                                      style: AppTextStyles.micro.copyWith(
                                        color: AppColors.goldLight,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],

                      // ── Blocked reason message (if applicable) ────────────────
                      if (item.isEquipped &&
                          !widget.canDirectUnequip &&
                          widget.unequipBlockedReason != null) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs + 2,
                          ),
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusSm,
                            ),
                            border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            widget.unequipBlockedReason!,
                            style: AppTextStyles.captionBold.copyWith(
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],

                      // ── Bottom Touch Action Deck (Equip, Enhance, Discard, Lock, etc.) ─
                      if (!widget.infoOnly) ...<Widget>[
                        primaryButton,
                        const SizedBox(height: AppSpacing.sm),

                        // Secondary Feature Action Buttons (Enhance, Socket, Salvage)
                        if (canEquip && !item.isEquipped) ...<Widget>[
                          Row(
                            children: <Widget>[
                              if (widget.onEnhance != null ||
                                  widget.actions.onEnhance != null)
                                Expanded(
                                  child: InventoryDialogActionButton(
                                    label: 'GELİŞTİR (+15)',
                                    onPressed: () async {
                                      await AionHaptics.craftSuccess();
                                      if (widget.onEnhance != null) {
                                        await widget.onEnhance!(item);
                                      } else {
                                        await widget.actions.onEnhance?.call(item);
                                      }
                                      if (mounted) Navigator.of(context).pop();
                                    },
                                    isPrimary: false,
                                    icon: Icons.hardware_rounded,
                                    accentColor: AppColors.warningSolar,
                                  ),
                                ),
                              if ((widget.onEnhance != null ||
                                      widget.actions.onEnhance != null) &&
                                  widget.actions.onSocket != null)
                                const SizedBox(width: 6),
                              if (widget.actions.onSocket != null)
                                Expanded(
                                  child: InventoryDialogActionButton(
                                    label: 'SOKETLE',
                                    onPressed: () async {
                                      await AionHaptics.slotSelect();
                                      await widget.actions.onSocket?.call(item);
                                      if (mounted) Navigator.of(context).pop();
                                    },
                                    isPrimary: false,
                                    icon: Icons.diamond_outlined,
                                    accentColor: AppColors.accentBlue,
                                  ),
                                ),
                              if (widget.actions.onSalvage != null) ...<Widget>[
                                const SizedBox(width: 6),
                                Expanded(
                                  child: InventoryDialogActionButton(
                                    label: 'AYRIŞTIR',
                                    onPressed: () async {
                                      await AionHaptics.craftSuccess();
                                      await widget.actions.onSalvage?.call(item);
                                      if (mounted) Navigator.of(context).pop();
                                    },
                                    isPrimary: false,
                                    icon: Icons.auto_fix_normal_rounded,
                                    accentColor: AppColors.accentPurple,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],

                        // Utility Action Deck (Split, Sell, Discard)
                        Row(
                          children: <Widget>[
                            if (canSplit) ...<Widget>[
                              Expanded(
                                child: InventoryDialogActionButton(
                                  label: 'BÖL',
                                  onPressed: () async {
                                    await AionHaptics.slotSelect();
                                    await widget.actions.onSplit?.call(item);
                                    if (mounted) Navigator.of(context).pop();
                                  },
                                  isPrimary: false,
                                  icon: Icons.call_split_rounded,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (canSell) ...<Widget>[
                              Expanded(
                                child: InventoryDialogActionButton(
                                  label: sellLabel,
                                  onPressed: () async {
                                    await AionHaptics.craftSuccess();
                                    await widget.actions.onSell?.call(item);
                                    if (mounted) Navigator.of(context).pop();
                                  },
                                  isPrimary: false,
                                  icon: Icons.monetization_on_outlined,
                                  accentColor: AppColors.gold,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (!item.isEquipped &&
                                (widget.onDiscard != null ||
                                    widget.actions.onDelete != null))
                              Expanded(
                                child: InventoryDialogActionButton(
                                  label: 'SİL',
                                  onPressed: _handleDiscard,
                                  isPrimary: false,
                                  icon: Icons.delete_outline_rounded,
                                  isDanger: true,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Standalone Bento Stat Diff Chip displaying an attribute value with optional live diff arrow.
class InventoryStatDiffChip extends StatelessWidget {
  const InventoryStatDiffChip({
    super.key,
    required this.label,
    required this.value,
    this.highlightColor,
    this.diff,
  });

  final String label;
  final String value;
  final Color? highlightColor;
  final int? diff;

  @override
  Widget build(BuildContext context) {
    final bool hasDiff = diff != null && diff != 0;
    final bool isPositive = hasDiff && diff! > 0;

    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs + 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: hasDiff
              ? (isPositive
                  ? AppColors.success.withValues(alpha: 0.40)
                  : AppColors.danger.withValues(alpha: 0.40))
              : AppColors.borderFaint,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.micro.copyWith(
              color: AppColors.mutedTitanium,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Text(
                value,
                style: AppTextStyles.titleBold.copyWith(
                  color: highlightColor ?? AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
              if (hasDiff) ...<Widget>[
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: (isPositive ? AppColors.success : AppColors.danger)
                        .withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(
                      AppSpacing.radiusXs / 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        isPositive
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 13,
                        color: isPositive ? AppColors.success : AppColors.danger,
                      ),
                      Text(
                        '${isPositive ? '+' : ''}$diff',
                        style: AppTextStyles.micro.copyWith(
                          color: isPositive
                              ? AppColors.success
                              : AppColors.danger,
                          fontWeight: FontWeight.w900,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Standalone Glassmorphic Action Button with tactile state handling & haptic feedback.
class InventoryDialogActionButton extends StatelessWidget {
  const InventoryDialogActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.isPrimary,
    this.accentColor,
    this.secondaryColor,
    this.icon,
    this.isDanger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;
  final Color? accentColor;
  final Color? secondaryColor;
  final IconData? icon;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    final Color effectiveAccent = accentColor ??
        (isDanger
            ? AppColors.danger
            : (isPrimary ? AppColors.liquidGold : AppColors.textSecondary));
    final Color effectiveSecondary =
        secondaryColor ?? effectiveAccent.withValues(alpha: 0.75);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled
            ? null
            : () async {
                await AionHaptics.buttonTap();
                onPressed?.call();
              },
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: isPrimary ? 46 : 38,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            gradient: isPrimary && !disabled
                ? LinearGradient(
                    colors: <Color>[
                      effectiveAccent.withValues(alpha: 0.90),
                      effectiveSecondary.withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isPrimary
                ? (disabled ? AppColors.bgSurface.withValues(alpha: 0.3) : null)
                : (isDanger
                    ? AppColors.danger.withValues(alpha: 0.16)
                    : AppColors.bgCardElevated.withValues(alpha: 0.40)),
            border: Border.all(
              color: isPrimary && !disabled
                  ? AppColors.textPrimary.withValues(alpha: 0.45)
                  : (disabled
                      ? AppColors.borderFaint
                      : effectiveAccent.withValues(
                          alpha: isDanger ? 0.60 : 0.35,
                        )),
              width: isPrimary ? 1.4 : 1.0,
            ),
            boxShadow: isPrimary && !disabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: effectiveAccent.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 15,
                  color: disabled
                      ? AppColors.textDisabled
                      : (isPrimary ? AppColors.textPrimary : effectiveAccent),
                ),
                const SizedBox(width: AppSpacing.xs + 1),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.label.copyWith(
                    color: disabled
                        ? AppColors.textDisabled
                        : (isPrimary
                            ? AppColors.textPrimary
                            : (isDanger
                                ? AppColors.danger
                                : AppColors.textPrimary)),
                    fontSize: isPrimary ? 12.5 : 11,
                    fontWeight: FontWeight.w800,
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

/// Custom painter for glowing arcane runic circular geometry
class _ArcaneRuneCirclePainter extends CustomPainter {
  const _ArcaneRuneCirclePainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;

    final Paint outerPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final Paint innerPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Concentric arcane circles
    canvas.drawCircle(center, radius - 2, outerPaint);
    canvas.drawCircle(center, radius - 8, innerPaint);

    // Decorative arcane notches/ticks
    final Paint tickPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const int tickCount = 12;
    for (int i = 0; i < tickCount; i++) {
      final double angle = (i * 2 * math.pi) / tickCount;
      final double innerX = center.dx + (radius - 10) * math.cos(angle);
      final double innerY = center.dy + (radius - 10) * math.sin(angle);
      final double outerX = center.dx + (radius - 2) * math.cos(angle);
      final double outerY = center.dy + (radius - 2) * math.sin(angle);
      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ArcaneRuneCirclePainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
