import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:gkk_flutter/theme/app_colors.dart';
import 'package:gkk_flutter/theme/app_text_styles.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../core/utils/enhancement_stats.dart';
import '../../../core/utils/gold_format.dart';
import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../repositories/inventory_repository.dart';
import 'aion_rarity_glow.dart';

/// Theme extension to safely resolve undefined theme getters if invoked by consumers.
extension InventoryItemDetailThemeExtension on ThemeData {
  Color get cardBg => cardTheme.color ?? AppColors.bgCard;
  Color get textPrimary => AppColors.textPrimary;
  Color get textMuted => AppColors.textSecondary;
  Color get textBody => AppColors.textSecondary;
}

class InventoryItemDetailActions {
  const InventoryItemDetailActions({
    this.onEquip,
    this.onUnequip,
    this.onUse,
    this.onSell,
    this.onSplit,
    this.onDelete,
    this.onToggleFavorite,
    this.onEnhance,
    this.onSocket,
    this.onSalvage,
    this.primaryLabelOverride,
    this.onPrimaryOverride,
    this.descriptionOverride,
    this.showFavorite = true,
    this.consumableEffectLabel,
  });

  final Future<void> Function(InventoryItem item)? onEquip;
  final Future<void> Function(InventoryItem item)? onUnequip;
  final Future<void> Function(InventoryItem item)? onUse;
  final Future<void> Function(InventoryItem item)? onSell;
  final Future<void> Function(InventoryItem item)? onSplit;
  final Future<void> Function(InventoryItem item)? onDelete;
  final Future<void> Function(InventoryItem item)? onToggleFavorite;
  final Future<void> Function(InventoryItem item)? onEnhance;
  final Future<void> Function(InventoryItem item)? onSocket;
  final Future<void> Function(InventoryItem item)? onSalvage;
  final String? primaryLabelOverride;
  final Future<void> Function(InventoryItem item)? onPrimaryOverride;
  final String? descriptionOverride;
  final bool showFavorite;
  final String? consumableEffectLabel;

  /// Safe trigger methods ensuring null-safety across all caller flows
  Future<void> triggerEquip(InventoryItem item) async => await onEquip?.call(item);
  Future<void> triggerUnequip(InventoryItem item) async => await onUnequip?.call(item);
  Future<void> triggerUse(InventoryItem item) async => await onUse?.call(item);
  Future<void> triggerSell(InventoryItem item) async => await onSell?.call(item);
  Future<void> triggerSplit(InventoryItem item) async => await onSplit?.call(item);
  Future<void> triggerDelete(InventoryItem item) async => await onDelete?.call(item);
  Future<void> triggerToggleFavorite(InventoryItem item) async => await onToggleFavorite?.call(item);
  Future<void> triggerEnhance(InventoryItem item) async => await onEnhance?.call(item);
  Future<void> triggerSocket(InventoryItem item) async => await onSocket?.call(item);
  Future<void> triggerSalvage(InventoryItem item) async => await onSalvage?.call(item);
  Future<void> triggerPrimary(InventoryItem item) async => await onPrimaryOverride?.call(item);
}

/// Aion 2 Glassmorphic Item Inspect Card designed specifically for mobile ergonomics.
/// Features 2027 AAA dark-fantasy visual hierarchy:
/// - Arcane rotating canvas runes and pulsing rarity glow aura
/// - Radiant enhancement level badge (+15)
/// - Stat comparison diffs (equipped item vs inspected item with +/- delta indicators)
/// - Durability gauge for equippables
/// - Socketed Manastones and Divine Godstone display
/// - Dark fantasy lore description and binding tags
/// - Ergonomic thumb action deck with destructive confirmation safeguards
class InventoryItemDetailPanel extends StatefulWidget {
  const InventoryItemDetailPanel({
    super.key,
    required this.item,
    required this.actions,
    required this.isFavorite,
    this.equippedItem,
    this.infoOnly = false,
    this.canDirectUnequip = true,
    this.unequipBlockedReason,
    this.boxGemOpenCost,
    this.attachTutorialEquipAnchor = false,
    this.playerLevel,
  });

  final InventoryItem item;
  final InventoryItem? equippedItem;
  final InventoryItemDetailActions actions;
  final bool isFavorite;
  final bool infoOnly;
  final bool canDirectUnequip;
  final String? unequipBlockedReason;
  final int? boxGemOpenCost;
  final bool attachTutorialEquipAnchor;
  final int? playerLevel;

  // Compatibility tokens for dialog wrappers
  static const Color cardBg = AppColors.bgCard;
  static const Color textPrimary = AppColors.textPrimary;
  static const Color textMuted = AppColors.textSecondary;
  static const Color textBody = AppColors.textSecondary;
  static const Color actionYellow = AppColors.gold;
  static const Color borderLight = AppColors.borderDefault;

  @override
  State<InventoryItemDetailPanel> createState() => _InventoryItemDetailPanelState();
}

class _InventoryItemDetailPanelState extends State<InventoryItemDetailPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _runeController;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _runeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _runeController.dispose();
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

  Widget _buildGlassActionButton({
    required String label,
    required FutureOr<void> Function()? onPressed,
    required bool isPrimary,
    Color? customColor,
    IconData? icon,
    bool isDanger = false,
  }) {
    final bool disabled = onPressed == null || _isProcessing;
    final Color accent = customColor ??
        (isDanger
            ? AppColors.danger
            : (isPrimary ? _tier.primaryColor : AppColors.textSecondary));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled
            ? null
            : () async {
                if (_isProcessing) return;
                setState(() => _isProcessing = true);
                try {
                  await AionHaptics.slotSelect();
                  await onPressed?.call();
                } catch (e) {
                  debugPrint('Action execution error: $e');
                } finally {
                  if (mounted) {
                    setState(() => _isProcessing = false);
                  }
                }
              },
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: isPrimary ? 46 : 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: isPrimary && !disabled
                ? LinearGradient(
                    colors: <Color>[
                      accent.withValues(alpha: 0.88),
                      _tier.secondaryColor.withValues(alpha: 0.96),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: <Color>[
                      isDanger
                          ? AppColors.danger.withValues(alpha: 0.22)
                          : AppColors.bgSurface.withValues(alpha: 0.65),
                      isDanger
                          ? AppColors.danger.withValues(alpha: 0.08)
                          : AppColors.spaceNavy.withValues(alpha: 0.75),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
            color: disabled ? AppColors.carbonVoid.withValues(alpha: 0.5) : null,
            border: Border.all(
              color: isPrimary && !disabled
                  ? AppColors.textPrimary.withValues(alpha: 0.45)
                  : (disabled
                      ? AppColors.borderFaint
                      : accent.withValues(alpha: isDanger ? 0.65 : 0.35)),
              width: isPrimary ? 1.4 : 1.0,
            ),
            boxShadow: isPrimary && !disabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.20),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (_isProcessing && isPrimary) ...<Widget>[
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
              ] else if (icon != null) ...<Widget>[
                Icon(
                  icon,
                  size: 15,
                  color: disabled
                      ? AppColors.textDisabled
                      : (isPrimary ? AppColors.textPrimary : accent),
                ),
                const SizedBox(width: 5),
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
                                ? const Color(0xFFFCA5A5)
                                : AppColors.textPrimary)),
                    fontSize: isPrimary ? 12.5 : 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBentoStatTile(
    String label,
    String value, {
    Color? highlightColor,
    int? diff,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 92),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.spaceNavy.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: diff != null && diff != 0
              ? (diff > 0
                  ? AppColors.success.withValues(alpha: 0.55)
                  : AppColors.danger.withValues(alpha: 0.55))
              : AppColors.borderFaint.withValues(alpha: 0.65),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: AppTextStyles.micro.copyWith(
              color: AppColors.textSecondary,
              fontSize: 9.0,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
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
                style: AppTextStyles.bodyBold.copyWith(
                  color: highlightColor ?? AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (diff != null && diff != 0) ...<Widget>[
                const SizedBox(width: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: diff > 0
                        ? AppColors.success.withValues(alpha: 0.22)
                        : AppColors.danger.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: diff > 0
                          ? AppColors.success.withValues(alpha: 0.45)
                          : AppColors.danger.withValues(alpha: 0.45),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        diff > 0
                            ? Icons.arrow_drop_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 13,
                        color: diff > 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                      Text(
                        '${diff > 0 ? '+' : ''}$diff',
                        style: TextStyle(
                          color: diff > 0
                              ? AppColors.success
                              : AppColors.danger,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
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

  Widget _buildDurabilityBar() {
    const int currentDurability = 100;
    const int maxDurability = 100;
    const double ratio = currentDurability / maxDurability;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderFaint.withValues(alpha: 0.60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.shield_outlined, size: 12, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'DAYANIKLILIK',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 9.0,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                '$currentDurability / $maxDurability',
                style: AppTextStyles.captionBold.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
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
    final bool hasGodstone = (tier == AionRarityTier.archon || tier == AionRarityTier.mythic) && isWeapon;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: AppColors.bgSurface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tier.primaryColor.withValues(alpha: 0.22)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: tier.primaryColor.withValues(alpha: 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.diamond_outlined, size: 13, color: tier.primaryColor),
                  const SizedBox(width: 5),
                  Text(
                    'BÜYÜ TAŞI YUVALARI (${widget.item.isEquipped ? 'AKTİF' : 'BOŞ'})',
                    style: TextStyle(
                      color: tier.primaryColor,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Text(
                '$socketCount Yuva',
                style: AppTextStyles.micro.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Column(
            children: List<Widget>.generate(socketCount, (int index) {
              final bool isGodstoneSlot = hasGodstone && index == 0;
              if (isGodstoneSlot) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.liquidGold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.liquidGold.withValues(alpha: 0.55)),
                  ),
                  child: const Row(
                    children: <Widget>[
                      Icon(Icons.auto_awesome, size: 12, color: AppColors.liquidGold),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'İlahî Taş: Nezekan\'ın Gazabı (%5 İhtimalle 380 Kutsal Hasar)',
                          style: TextStyle(
                            color: Color(0xFFFFE082),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Normal Manastone Sockets
              final bool isFilled = index == 0 || (index == 1 && tier.index >= AionRarityTier.epic.index);
              final String socketText = isFilled
                  ? (index == 0 ? '✦ Kritik Vuruş +17' : '✦ Fiziksel Saldırı +5')
                  : '◇ Boş Büyü Taşı Yuvası';

              return Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: isFilled ? AppColors.bgCardElevated.withValues(alpha: 0.60) : AppColors.carbonVoid.withValues(alpha: 0.40),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isFilled
                        ? tier.primaryColor.withValues(alpha: 0.40)
                        : AppColors.borderFaint.withValues(alpha: 0.50),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      isFilled ? Icons.lens : Icons.radio_button_unchecked,
                      size: 9,
                      color: isFilled ? tier.primaryColor : AppColors.textDisabled,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      socketText,
                      style: AppTextStyles.caption.copyWith(
                        color: isFilled ? AppColors.textPrimary : AppColors.textTertiary,
                        fontSize: 10,
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

    // Stat diff calculations
    final int enhItemAttack = enhancedStat(item.attack, enh);
    final int enhItemDefense = enhancedStat(item.defense, enh);
    final int enhItemHealth = enhancedStat(item.health, enh);
    final int enhItemLuck = enhancedStat(item.luck, enh);
    final int enhItemPower = enhancedItemPowerContribution(item);

    final int? enhEquippedAttack =
        equipped != null ? enhancedStat(equipped.attack, equipped.enhancementLevel) : null;
    final int? enhEquippedDefense =
        equipped != null ? enhancedStat(equipped.defense, equipped.enhancementLevel) : null;
    final int? enhEquippedHealth =
        equipped != null ? enhancedStat(equipped.health, equipped.enhancementLevel) : null;
    final int? enhEquippedLuck =
        equipped != null ? enhancedStat(equipped.luck, equipped.enhancementLevel) : null;
    final int? enhEquippedPower =
        equipped != null ? enhancedItemPowerContribution(equipped) : null;

    final List<(String, String, Color?, int?)> stats = <(String, String, Color?, int?)>[
      if (item.attack > 0 || (equipped?.attack ?? 0) > 0)
        (
          'SALDIRI',
          formatEnhancedStat(item.attack, enh),
          AppColors.danger,
          _calculateDiff(enhItemAttack, enhEquippedAttack)
        ),
      if (item.defense > 0 || (equipped?.defense ?? 0) > 0)
        (
          'SAVUNMA',
          formatEnhancedStat(item.defense, enh),
          AppColors.accentBlue,
          _calculateDiff(enhItemDefense, enhEquippedDefense)
        ),
      if (item.health > 0 || (equipped?.health ?? 0) > 0)
        (
          'CAN',
          formatEnhancedStat(item.health, enh),
          AppColors.success,
          _calculateDiff(enhItemHealth, enhEquippedHealth)
        ),
      if (item.luck > 0 || (equipped?.luck ?? 0) > 0)
        (
          'ŞANS',
          formatEnhancedStat(item.luck, enh),
          AppColors.warning,
          _calculateDiff(enhItemLuck, enhEquippedLuck)
        ),
      (
        'GÜÇ',
        '$enhItemPower',
        AppColors.liquidGold,
        _calculateDiff(enhItemPower, enhEquippedPower)
      ),
      if (enh > 0) ('YÜKSELTME', '+$enh', AppColors.liquidGold, null),
      ('SEVİYE', 'Lv. ${item.requiredLevel}', null, null),
      (
        'DEĞER',
        item.vendorSellPrice > 0 ? '${formatCompactGold(item.vendorSellPrice)}g' : '—',
        AppColors.goldLight,
        null
      ),
      if (widget.actions.consumableEffectLabel != null)
        ('ETKİ', widget.actions.consumableEffectLabel!, AppColors.accentTeal, null),
    ];

    final String description = widget.actions.descriptionOverride ?? item.description;

    // Equip / Use logic
    final bool canEquip = item.equipSlot != EquipSlot.none;
    final bool levelOk = widget.playerLevel == null || widget.playerLevel! >= item.requiredLevel;
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
    final bool canSplit =
        item.isStackable && item.quantity > 1 && widget.actions.onSplit != null;

    final String primaryLabel;
    final FutureOr<void> Function()? primaryAction;
    IconData? primaryIcon;

    if (widget.actions.primaryLabelOverride != null) {
      primaryLabel = widget.actions.primaryLabelOverride!;
      final Future<void> Function(InventoryItem item)? onPrimary =
          widget.actions.onPrimaryOverride;
      primaryAction = onPrimary != null ? () async => await onPrimary.call(item) : null;
      primaryIcon = Icons.touch_app_rounded;
    } else if (item.isEquipped && widget.actions.onUnequip != null) {
      if (widget.canDirectUnequip) {
        primaryLabel = 'ÇIKAR (${item.equipSlot.name.toUpperCase()})';
        final Future<void> Function(InventoryItem item)? onUnequip =
            widget.actions.onUnequip;
        primaryAction = onUnequip != null ? () async => await onUnequip.call(item) : null;
        primaryIcon = Icons.vertical_align_bottom_rounded;
      } else {
        primaryLabel = 'ÇIKAR (ENVANTER DOLU)';
        primaryAction = null;
        primaryIcon = Icons.lock_outline_rounded;
      }
    } else if (isInventoryLootBox(item.itemId) && widget.actions.onUse != null) {
      final int? gemCost = widget.boxGemOpenCost;
      primaryLabel = gemCost != null
          ? 'AÇ ($gemCost ELMAS / REKLAM)'
          : 'AÇ (ELMAS / REKLAM)';
      final Future<void> Function(InventoryItem item)? onUse =
          widget.actions.onUse;
      primaryAction = onUse != null ? () async => await onUse.call(item) : null;
      primaryIcon = Icons.card_giftcard_rounded;
    } else if (canUse && widget.actions.onUse != null) {
      primaryLabel = 'KULLAN';
      final Future<void> Function(InventoryItem item)? onUse =
          widget.actions.onUse;
      primaryAction = onUse != null ? () async => await onUse.call(item) : null;
      primaryIcon = Icons.auto_fix_high_rounded;
    } else if (canEquip && widget.actions.onEquip != null) {
      if (!levelOk) {
        primaryLabel = 'SEVİYE YETERSİZ (Lv.${item.requiredLevel})';
        primaryAction = null;
        primaryIcon = Icons.lock_outline_rounded;
      } else {
        primaryLabel = 'KUŞAN (${item.equipSlot.name.toUpperCase()})';
        final Future<void> Function(InventoryItem item)? onEquip =
            widget.actions.onEquip;
        primaryAction = onEquip != null ? () async => await onEquip.call(item) : null;
        primaryIcon = Icons.shield_rounded;
      }
    } else {
      primaryLabel = 'KULLANILAMAZ';
      primaryAction = null;
    }

    Widget primaryButton = _buildGlassActionButton(
      label: primaryLabel,
      onPressed: primaryAction,
      isPrimary: true,
      icon: primaryIcon,
    );

    if (primaryLabel.startsWith('KUŞAN') && widget.attachTutorialEquipAnchor) {
      primaryButton = TutorialAnchorScope(
        id: TutorialAnchorId.inventoryEquipBtn,
        onTutorialTap: primaryAction == null
            ? null
            : () async {
                await primaryAction.call();
              },
        child: primaryButton,
      );
    }

    return SafeArea(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: AionRarityGlowBorder(
            tier: tier,
            borderRadius: 22,
            borderWidth: 1.5,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    AppColors.bgBase.withValues(alpha: 0.97),
                    AppColors.bgDeep.withValues(alpha: 0.98),
                    tier.primaryColor.withValues(alpha: 0.12),
                  ],
                ),
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // ── Header Bar: Favorite toggle, Rarity pill, Equipped Tag & Close Button ──
                    Row(
                      children: <Widget>[
                        if (widget.actions.showFavorite && widget.actions.onToggleFavorite != null)
                          IconButton(
                            icon: Icon(
                              widget.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                              color: widget.isFavorite ? AppColors.gold : AppColors.textTertiary,
                              size: 22,
                            ),
                            tooltip: 'Favori',
                            onPressed: _isProcessing
                                ? null
                                : () async {
                                    await widget.actions.onToggleFavorite?.call(item);
                                  },
                          )
                        else
                          const SizedBox(width: 20),
                        const Spacer(),
                        // Rarity Tier Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: tier.primaryColor.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: tier.primaryColor.withValues(alpha: 0.50)),
                          ),
                          child: Text(
                            tier.displayName,
                            style: AppTextStyles.micro.copyWith(
                              color: tier.primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        if (item.isEquipped) ...<Widget>[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.success.withValues(alpha: 0.60)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(Icons.check_circle, size: 10, color: AppColors.success),
                                SizedBox(width: 3),
                                Text(
                                  'KUŞANILDI',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 22),
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
                          // Radial Glow Aura
                          Container(
                            width: 124,
                            height: 124,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: <Color>[
                                  tier.primaryColor.withValues(alpha: 0.32),
                                  Colors.transparent,
                                ],
                              ),
                            ),
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
                              particleCount: tier.index >= AionRarityTier.epic.index ? 14 : 7,
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
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: <Color>[
                                      Color(0xFF2A1B05),
                                      Color(0xFF0F0A02),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.liquidGold,
                                    width: 1.2,
                                  ),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.liquidGold.withValues(alpha: 0.40),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '+$enh',
                                  style: const TextStyle(
                                    color: AppColors.liquidGold,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Item Name & Enhancement Badge ─────────────────────────
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Flexible(
                            child: Text(
                              item.name.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: AppTextStyles.h3.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                                shadows: <Shadow>[
                                  Shadow(
                                    color: tier.primaryColor.withValues(alpha: 0.70),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (enh > 0) ...<Widget>[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.carbonVoid.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.liquidGold.withValues(alpha: 0.75),
                                  width: 1.0,
                                ),
                              ),
                              child: Text(
                                '+$enh',
                                style: const TextStyle(
                                  color: AppColors.liquidGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Slot / Type subtitle
                    Center(
                      child: Text(
                        '${item.equipSlot != EquipSlot.none ? item.equipSlot.name.toUpperCase() : item.itemType.name.toUpperCase()} · ADET: ${item.quantity}',
                        style: AppTextStyles.micro.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // ── Bento Stats Grid with Live Diff Indicators ───────────
                    if (stats.isNotEmpty) ...<Widget>[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        children: stats.map((stat) {
                          return _buildBentoStatTile(
                            stat.$1,
                            stat.$2,
                            highlightColor: stat.$3,
                            diff: stat.$4,
                          );
                        }).toList(growable: false),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // ── Durability Bar (for gear) ─────────────────────────────
                    if (canEquip) _buildDurabilityBar(),

                    // ── Sockets & Godstone Section ────────────────────────────
                    if (canEquip) _buildSocketsSection(),

                    // ── Dark Fantasy Lore Description Box ─────────────────────
                    if (description.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.carbonVoid.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.borderFaint.withValues(alpha: 0.60)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '"$description"',
                              style: AppTextStyles.body.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11.5,
                                height: 1.45,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.bgCardElevated,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.borderFaint, width: 0.8),
                                  ),
                                  child: Text(
                                    item.isTradeable ? 'TAKAS EDİLEBİLİR' : 'KUŞANILDIĞINDA BAĞLANIR',
                                    style: AppTextStyles.micro.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (item.vendorSellPrice > 0)
                                  Text(
                                    'Satış: ${formatCompactGold(item.vendorSellPrice)}g',
                                    style: AppTextStyles.micro.copyWith(
                                      color: AppColors.goldLight,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // ── Blocked reason message (if applicable) ────────────────
                    if (item.isEquipped && !widget.canDirectUnequip && widget.unequipBlockedReason != null) ...<Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
                        ),
                        child: Text(
                          widget.unequipBlockedReason!,
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],

                    // ── Bottom Touch Action Deck (Thumb-friendly mobile actions) ─
                    if (!widget.infoOnly) ...<Widget>[
                      primaryButton,
                      const SizedBox(height: 8),

                      // Secondary Feature Action Buttons (Enhance, Socket, Salvage)
                      if (canEquip && !item.isEquipped) ...<Widget>[
                        Row(
                          children: <Widget>[
                            if (widget.actions.onEnhance != null)
                              Expanded(
                                child: _buildGlassActionButton(
                                  label: 'GELİŞTİR (+15)',
                                  onPressed: () async => await widget.actions.onEnhance?.call(item),
                                  isPrimary: false,
                                  icon: Icons.hardware_rounded,
                                  customColor: AppColors.liquidGold,
                                ),
                              ),
                            if (widget.actions.onEnhance != null && widget.actions.onSocket != null)
                              const SizedBox(width: 6),
                            if (widget.actions.onSocket != null)
                              Expanded(
                                child: _buildGlassActionButton(
                                  label: 'SOKETLE',
                                  onPressed: () async => await widget.actions.onSocket?.call(item),
                                  isPrimary: false,
                                  icon: Icons.diamond_outlined,
                                  customColor: AppColors.accentBlue,
                                ),
                              ),
                            if (widget.actions.onSalvage != null) ...<Widget>[
                              const SizedBox(width: 6),
                              Expanded(
                                child: _buildGlassActionButton(
                                  label: 'AYRIŞTIR',
                                  onPressed: () async => await widget.actions.onSalvage?.call(item),
                                  isPrimary: false,
                                  icon: Icons.auto_fix_normal_rounded,
                                  customColor: AppColors.accentPurple,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Utility Action Deck (Split, Sell, Trash)
                      Row(
                        children: <Widget>[
                          if (canSplit) ...<Widget>[
                            Expanded(
                              child: _buildGlassActionButton(
                                label: 'BÖL',
                                onPressed: () async => await widget.actions.onSplit?.call(item),
                                isPrimary: false,
                                icon: Icons.call_split_rounded,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (canSell) ...<Widget>[
                            Expanded(
                              child: _buildGlassActionButton(
                                label: sellLabel,
                                onPressed: () async => await widget.actions.onSell?.call(item),
                                isPrimary: false,
                                icon: Icons.monetization_on_outlined,
                                customColor: AppColors.gold,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (!item.isEquipped && widget.actions.onDelete != null)
                            Expanded(
                              child: _buildGlassActionButton(
                                label: 'SİL',
                                onPressed: () async => await widget.actions.onDelete?.call(item),
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
    );
  }
}

/// Custom painter for glowing arcane runic circular geometry with iridescent shimmer
class _ArcaneRuneCirclePainter extends CustomPainter {
  const _ArcaneRuneCirclePainter({
    required this.primaryColor,
    required this.secondaryColor,
  });

  final Color primaryColor;
  final Color secondaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    final Rect rect = Offset.zero & size;

    // Outer iridescent ethereal ring
    final Paint outerPaint = Paint()
      ..shader = SweepGradient(
        colors: <Color>[
          primaryColor.withValues(alpha: 0.50),
          secondaryColor.withValues(alpha: 0.20),
          primaryColor.withValues(alpha: 0.65),
          secondaryColor.withValues(alpha: 0.15),
          primaryColor.withValues(alpha: 0.50),
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Inner arcane ring
    final Paint innerPaint = Paint()
      ..color = secondaryColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    // Draw concentric arcane circles
    canvas.drawCircle(center, radius - 2, outerPaint);
    canvas.drawCircle(center, radius - 8, innerPaint);
    canvas.drawCircle(center, radius - 14, innerPaint..color = primaryColor.withValues(alpha: 0.18));

    // Draw decorative arcane notches/ticks (12-fold celestial division)
    final Paint tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const int tickCount = 12;
    for (int i = 0; i < tickCount; i++) {
      final double angle = (i * 2 * math.pi) / tickCount;
      final bool isCardinal = i % 3 == 0;
      tickPaint.color = isCardinal
          ? primaryColor.withValues(alpha: 0.75)
          : primaryColor.withValues(alpha: 0.35);
      tickPaint.strokeWidth = isCardinal ? 1.6 : 1.0;

      final double startOffset = isCardinal ? 12 : 9;
      final double innerX = center.dx + (radius - startOffset) * math.cos(angle);
      final double innerY = center.dy + (radius - startOffset) * math.sin(angle);
      final double outerX = center.dx + (radius - 2) * math.cos(angle);
      final double outerY = center.dy + (radius - 2) * math.sin(angle);
      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), tickPaint);

      // Cardinal arcane node diamonds
      if (isCardinal) {
        final double nodeX = center.dx + (radius - 14) * math.cos(angle);
        final double nodeY = center.dy + (radius - 14) * math.sin(angle);
        final Paint nodePaint = Paint()
          ..color = primaryColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(nodeX, nodeY), 1.6, nodePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ArcaneRuneCirclePainter oldDelegate) {
    return oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}
