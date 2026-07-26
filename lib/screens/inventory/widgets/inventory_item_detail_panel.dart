import 'package:flutter/material.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../core/utils/gold_format.dart';
import '../../../core/tutorial/tutorial_anchor.dart';
import '../../../core/tutorial/tutorial_track.dart';
import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../repositories/inventory_repository.dart';

class InventoryItemDetailActions {
  const InventoryItemDetailActions({
    this.onEquip,
    this.onUnequip,
    this.onUse,
    this.onSell,
    this.onSplit,
    this.onDelete,
    this.onToggleFavorite,
    this.primaryLabelOverride,
    this.onPrimaryOverride,
    this.descriptionOverride,
    this.showFavorite = true,
  });

  final Future<void> Function(InventoryItem item)? onEquip;
  final Future<void> Function(InventoryItem item)? onUnequip;
  final Future<void> Function(InventoryItem item)? onUse;
  final Future<void> Function(InventoryItem item)? onSell;
  final Future<void> Function(InventoryItem item)? onSplit;
  final Future<void> Function(InventoryItem item)? onDelete;
  final Future<void> Function(InventoryItem item)? onToggleFavorite;
  final String? primaryLabelOverride;
  final Future<void> Function(InventoryItem item)? onPrimaryOverride;
  final String? descriptionOverride;
  final bool showFavorite;
}

/// Envanter grid tap popup — birebir tasarım.
class InventoryItemDetailPanel extends StatelessWidget {
  const InventoryItemDetailPanel({
    super.key,
    required this.item,
    required this.actions,
    required this.isFavorite,
    this.infoOnly = false,
    this.canDirectUnequip = true,
    this.unequipBlockedReason,
  });

  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color actionYellow = Color(0xFFF2D74C);
  static const Color textPrimary = Color(0xFF111111);
  static const Color textMuted = Color(0xFF999999);
  static const Color textBody = Color(0xFF888888);
  static const Color borderLight = Color(0xFFD4D4D4);

  final InventoryItem item;
  final InventoryItemDetailActions actions;
  final bool isFavorite;
  final bool infoOnly;
  final bool canDirectUnequip;
  final String? unequipBlockedReason;

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
                ? (disabled ? const Color(0xFFE8E8E8) : actionYellow)
                : cardBg,
            border: isPrimary
                ? null
                : Border.all(
                    color: disabled ? const Color(0xFFEEEEEE) : borderLight,
                    width: 1,
                  ),
            boxShadow: isPrimary && !disabled
                ? <BoxShadow>[
                    BoxShadow(
                      color: actionYellow.withValues(alpha: 0.35),
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
                color: disabled ? const Color(0xFFBDBDBD) : textPrimary,
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
            color: textMuted,
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
    final List<(String, String)> stats = <(String, String)>[
      ('SALDIRI', '${item.attack}'),
      ('SAVUNMA', '${item.defense}'),
      ('GUC', '${item.power}'),
      ('SEVIYE', 'Lv. ${item.requiredLevel}'),
      ('DEGER', item.vendorSellPrice > 0 ? '${formatCompactGold(item.vendorSellPrice)}g' : '-'),
    ];

    final String footerRight = item.vendorSellPrice > 0
        ? '${formatCompactGold(item.vendorSellPrice)}g'
        : 'Lv. ${item.requiredLevel}';
    final String description =
        actions.descriptionOverride ?? item.description;

    if (infoOnly) {
      return Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
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
                    _buildItemIconWithShadow(item),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: textMuted),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'ESYA ADI',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.name.toUpperCase(),
                  style: const TextStyle(
                    color: textPrimary,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${item.rarity.name.toUpperCase()} · ${item.equipSlot != EquipSlot.none ? item.equipSlot.name.toUpperCase() : item.itemType.name.toUpperCase()}',
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: const TextStyle(
                      color: textBody,
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
                      'x${item.quantity}',
                      style: const TextStyle(
                        color: textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      footerRight,
                      style: const TextStyle(
                        color: textMuted,
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

    final bool canEquip = item.equipSlot != EquipSlot.none;
    final bool canUse =
        isStatResetScroll(item.itemId) ||
        isNameChangeScroll(item.itemId) ||
        item.itemType == ItemType.potion ||
        item.itemType == ItemType.consumable ||
        item.potionType != PotionType.none ||
        item.energyRestore > 0 ||
        item.healthRestore > 0;
    final bool canSell = !item.isEquipped &&
        item.vendorSellPrice > 0 &&
        item.isTradeable &&
        actions.onSell != null;
    final String sellLabel = canSell
        ? 'SAT (${formatCompactGold(item.vendorSellPrice)})'
        : 'SAT';
    final bool canSplit =
        item.isStackable && item.quantity > 1 && actions.onSplit != null;

    final String primaryLabel;
    final VoidCallback? primaryAction;
    if (actions.primaryLabelOverride != null) {
      primaryLabel = actions.primaryLabelOverride!;
      primaryAction = actions.onPrimaryOverride != null
          ? () => actions.onPrimaryOverride!(item)
          : null;
    } else if (item.isEquipped && actions.onUnequip != null) {
      if (canDirectUnequip) {
        primaryLabel = 'CIKAR (${item.equipSlot.name.toUpperCase()})';
        primaryAction = () => actions.onUnequip!(item);
      } else {
        primaryLabel = 'CIKAR (ENVANTER DOLU)';
        primaryAction = null;
      }
    } else if (isInventoryLootBox(item.itemId) && actions.onUse != null) {
      primaryLabel = 'AC (💎 / 📺)';
      primaryAction = () => actions.onUse!(item);
    } else if (canUse && actions.onUse != null) {
      primaryLabel = 'KULLAN';
      primaryAction = () => actions.onUse!(item);
    } else if (canEquip && actions.onEquip != null) {
      primaryLabel = 'KUSAN (${item.equipSlot.name.toUpperCase()})';
      primaryAction = () => actions.onEquip!(item);
    } else {
      primaryLabel = 'KULLANILAMAZ';
      primaryAction = null;
    }

    Widget primaryButton = _buildActionButton(
      label: primaryLabel,
      onPressed: primaryAction,
      isPrimary: true,
    );
    if (primaryLabel.startsWith('KUSAN')) {
      primaryButton = TutorialAnchorScope(
        id: TutorialAnchorId.inventoryEquipBtn,
        child: primaryButton,
      );
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardBg,
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
                  _buildItemIconWithShadow(item),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        primaryButton,
                        if (item.isEquipped &&
                            !canDirectUnequip &&
                            unequipBlockedReason != null) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            unequipBlockedReason!,
                            style: const TextStyle(
                              color: Color(0xFFE89558),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        _buildActionButton(
                          label: 'BOL',
                          onPressed: canSplit ? () => actions.onSplit!(item) : null,
                          isPrimary: false,
                        ),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          label: 'COP',
                          onPressed: actions.onDelete != null
                              ? () => actions.onDelete!(item)
                              : null,
                          isPrimary: false,
                        ),
                        const SizedBox(height: 8),
                        _buildActionButton(
                          label: sellLabel,
                          onPressed: canSell ? () => actions.onSell!(item) : null,
                          isPrimary: false,
                        ),
                      ],
                    ),
                  ),
                  if (actions.showFavorite && actions.onToggleFavorite != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => actions.onToggleFavorite!(item),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isFavorite
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: isFavorite
                                ? const Color(0xFFE6B800)
                                : textMuted,
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
                  color: textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.name.toUpperCase(),
                style: const TextStyle(
                  color: textPrimary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${item.rarity.name.toUpperCase()} · ${item.equipSlot != EquipSlot.none ? item.equipSlot.name.toUpperCase() : item.itemType.name.toUpperCase()}',
                style: const TextStyle(
                  color: textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              if (description.isNotEmpty)
                Text(
                  description,
                  style: const TextStyle(
                    color: textBody,
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
                    'x${item.quantity}',
                    style: const TextStyle(
                      color: textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    footerRight,
                    style: const TextStyle(
                      color: textMuted,
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
