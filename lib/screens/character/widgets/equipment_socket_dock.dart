import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../models/inventory_model.dart';
import '../../../models/item_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// Equipment slot category for Aion 2 high-fantasy gear sorting
enum EquipmentSlotCategory {
  armor,
  weapon,
  accessory,
  celestial,
}

/// Aion 2 Rarity Tiers reflecting AAA modern high-fantasy aesthetics
enum AionEquipmentRarity {
  common,
  rare,
  heroic,
  fabled,
  eternal;

  static AionEquipmentRarity fromRarityString(String? rarity, {int enhancementLevel = 0}) {
    if (rarity == null) return AionEquipmentRarity.common;
    final String r = rarity.toLowerCase().trim();
    if (r == 'eternal' || r == 'mythic' || r == 'archon' || enhancementLevel >= 13) {
      return AionEquipmentRarity.eternal;
    }
    if (r == 'fabled' || r == 'legendary' || enhancementLevel >= 10) {
      return AionEquipmentRarity.fabled;
    }
    if (r == 'heroic' || r == 'epic' || enhancementLevel >= 7) {
      return AionEquipmentRarity.heroic;
    }
    if (r == 'rare' || enhancementLevel >= 4) {
      return AionEquipmentRarity.rare;
    }
    return AionEquipmentRarity.common;
  }

  Color get primaryColor => switch (this) {
        AionEquipmentRarity.common => AppColors.mutedTitanium, // Mithril Slate
        AionEquipmentRarity.rare => AppColors.accentTeal,       // Verdant Jade
        AionEquipmentRarity.heroic => AppColors.accentBlue,    // Celestial Azure
        AionEquipmentRarity.fabled => AppColors.liquidGold,    // Radiant Amber Gold
        AionEquipmentRarity.eternal => AppColors.accentPurple, // Imperial Prismatic
      };

  Color get secondaryColor => switch (this) {
        AionEquipmentRarity.common => AppColors.darkObsidian,
        AionEquipmentRarity.rare => const Color(0xFF059669),
        AionEquipmentRarity.heroic => AppColors.accentBlueDim,
        AionEquipmentRarity.fabled => const Color(0xFFD97706),
        AionEquipmentRarity.eternal => AppColors.cyberFuchsia,
      };

  Color get glowColor => primaryColor.withValues(alpha: switch (this) {
        AionEquipmentRarity.common => 0.22,
        AionEquipmentRarity.rare => 0.40,
        AionEquipmentRarity.heroic => 0.55,
        AionEquipmentRarity.fabled => 0.70,
        AionEquipmentRarity.eternal => 0.85,
      });

  String get displayName => switch (this) {
        AionEquipmentRarity.common => 'Sıradan',
        AionEquipmentRarity.rare => 'Nadir',
        AionEquipmentRarity.heroic => 'Kahramansı',
        AionEquipmentRarity.fabled => 'Efsanevi',
        AionEquipmentRarity.eternal => 'Kozmik / Ebedi',
      };
}

/// Dock layout mode: flanked columns with radial curvature or compact
enum EquipmentDockLayout {
  radial,
  flanked,
  compact,
}

/// Equipment socket descriptor definition
class EquipmentSlotDef {
  const EquipmentSlotDef({
    required this.slotKey,
    required this.name,
    required this.icon,
    required this.equipSlot,
    this.subtitle,
    this.category = EquipmentSlotCategory.armor,
    this.maxGemSockets = 3,
    this.isLocked = false,
    this.unlockLevel,
  });

  final String slotKey;
  final String name;
  final IconData icon;
  final EquipSlot equipSlot;
  final String? subtitle;
  final EquipmentSlotCategory category;
  final int maxGemSockets;
  final bool isLocked;
  final int? unlockLevel;
}

/// 6 Left Flank Slots in Aion 2 radial layout:
/// Helmet (head), Pauldrons (pauldrons), Chest (chest), Gloves (gloves), Greaves (legs), Wings (wings).
const List<EquipmentSlotDef> kLeftEquipmentSlots = <EquipmentSlotDef>[
  EquipmentSlotDef(
    slotKey: 'head',
    name: 'Miğfer',
    subtitle: 'Helmet',
    icon: Icons.shield_moon_rounded,
    equipSlot: EquipSlot.head,
    category: EquipmentSlotCategory.armor,
    maxGemSockets: 3,
  ),
  EquipmentSlotDef(
    slotKey: 'pauldrons',
    name: 'Omuzluk',
    subtitle: 'Pauldrons',
    icon: Icons.security_rounded,
    equipSlot: EquipSlot.none,
    category: EquipmentSlotCategory.armor,
    maxGemSockets: 3,
  ),
  EquipmentSlotDef(
    slotKey: 'chest',
    name: 'Zırh',
    subtitle: 'Chest Armor',
    icon: Icons.shield_rounded,
    equipSlot: EquipSlot.chest,
    category: EquipmentSlotCategory.armor,
    maxGemSockets: 4,
  ),
  EquipmentSlotDef(
    slotKey: 'gloves',
    name: 'Eldiven',
    subtitle: 'Gloves',
    icon: Icons.front_hand_rounded,
    equipSlot: EquipSlot.gloves,
    category: EquipmentSlotCategory.armor,
    maxGemSockets: 3,
  ),
  EquipmentSlotDef(
    slotKey: 'legs',
    name: 'Pantolon',
    subtitle: 'Greaves',
    icon: Icons.accessibility_new_rounded,
    equipSlot: EquipSlot.legs,
    category: EquipmentSlotCategory.armor,
    maxGemSockets: 4,
  ),
  EquipmentSlotDef(
    slotKey: 'wings',
    name: 'Kanatlar',
    subtitle: 'Celestial Wings',
    icon: Icons.flight_rounded,
    equipSlot: EquipSlot.none,
    category: EquipmentSlotCategory.celestial,
    maxGemSockets: 4,
  ),
];

/// 6 Right Flank Slots in Aion 2 radial layout:
/// Main Hand (weapon at index 0 for test compatibility), Off Hand (off_hand), Boots (boots),
/// Necklace (necklace), Earring (earring), Ring (ring).
const List<EquipmentSlotDef> kRightEquipmentSlots = <EquipmentSlotDef>[
  EquipmentSlotDef(
    slotKey: 'weapon',
    name: 'Silah',
    subtitle: 'Main Hand',
    icon: Icons.sports_martial_arts_rounded,
    equipSlot: EquipSlot.weapon,
    category: EquipmentSlotCategory.weapon,
    maxGemSockets: 5,
  ),
  EquipmentSlotDef(
    slotKey: 'off_hand',
    name: 'Yan El',
    subtitle: 'Off Hand / Shield',
    icon: Icons.shield_outlined,
    equipSlot: EquipSlot.none,
    category: EquipmentSlotCategory.weapon,
    maxGemSockets: 3,
  ),
  EquipmentSlotDef(
    slotKey: 'boots',
    name: 'Çizme',
    subtitle: 'Boots',
    icon: Icons.roller_skating_rounded,
    equipSlot: EquipSlot.boots,
    category: EquipmentSlotCategory.armor,
    maxGemSockets: 3,
  ),
  EquipmentSlotDef(
    slotKey: 'necklace',
    name: 'Kolye',
    subtitle: 'Necklace',
    icon: Icons.all_inclusive_rounded,
    equipSlot: EquipSlot.necklace,
    category: EquipmentSlotCategory.accessory,
    maxGemSockets: 2,
  ),
  EquipmentSlotDef(
    slotKey: 'earring',
    name: 'Küpe',
    subtitle: 'Earring',
    icon: Icons.hearing_rounded,
    equipSlot: EquipSlot.none,
    category: EquipmentSlotCategory.accessory,
    maxGemSockets: 2,
  ),
  EquipmentSlotDef(
    slotKey: 'ring',
    name: 'Yüzük',
    subtitle: 'Ring',
    icon: Icons.fingerprint_rounded,
    equipSlot: EquipSlot.ring,
    category: EquipmentSlotCategory.accessory,
    maxGemSockets: 2,
  ),
];

/// Complete registry of all 12 Aion 2 mobile equipment slots
const List<EquipmentSlotDef> kAion2AllEquipmentSlots = <EquipmentSlotDef>[
  ...kLeftEquipmentSlots,
  ...kRightEquipmentSlots,
];

/// Modern 2027 Aion 2 Mobile Equipment Socket Dock:
/// Radial/Flanked constellation framing the 3D character viewport.
/// Supports 12 equipment slots, breathing ethereal glow shaders, enhancement badges,
/// gem insertion sockets, lock/unlocked indicators, and quick comparison tooltips.
class EquipmentSocketDock extends StatelessWidget {
  const EquipmentSocketDock({
    super.key,
    required this.equippedItems,
    required this.onSlotTap,
    this.compact = false,
    this.layout = EquipmentDockLayout.radial,
    this.onSlotLongPress,
    this.highlightedSlotKey,
    this.slotSize,
    this.lockedSlotKeys,
    this.onLockedSlotTap,
  });

  final Map<String, InventoryItem?> equippedItems;
  final void Function(EquipmentSlotDef def, InventoryItem? item) onSlotTap;
  final bool compact;
  final EquipmentDockLayout layout;
  final void Function(EquipmentSlotDef def, InventoryItem? item)? onSlotLongPress;
  final String? highlightedSlotKey;
  final double? slotSize;
  final Set<String>? lockedSlotKeys;
  final void Function(EquipmentSlotDef def)? onLockedSlotTap;

  @override
  Widget build(BuildContext context) {
    final double effectiveSlotSize = slotSize ?? (compact ? 44.0 : 50.0);
    final double verticalSpacing = compact ? AppSpacing.xs : AppSpacing.radiusXs;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Left Radial Arc Column
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List<Widget>.generate(kLeftEquipmentSlots.length, (int index) {
            final EquipmentSlotDef def = kLeftEquipmentSlots[index];
            final bool isLocked = lockedSlotKeys?.contains(def.slotKey) ?? def.isLocked;
            final double curveOffset = _calculateRadialCurveOffset(
              index,
              kLeftEquipmentSlots.length,
              isLeft: true,
            );

            return Padding(
              padding: EdgeInsets.symmetric(vertical: verticalSpacing),
              child: Transform.translate(
                offset: Offset(layout == EquipmentDockLayout.flanked ? 0.0 : curveOffset, 0),
                child: _EquipmentSocketButton(
                  slotDef: def,
                  item: equippedItems[def.slotKey],
                  size: effectiveSlotSize,
                  isHighlighted: highlightedSlotKey == def.slotKey,
                  isLocked: isLocked,
                  onTap: () {
                    if (isLocked) {
                      HapticFeedback.heavyImpact();
                      if (onLockedSlotTap != null) {
                        onLockedSlotTap!(def);
                      } else {
                        _showLockedSlotNotice(context, def);
                      }
                      return;
                    }
                    HapticFeedback.lightImpact();
                    onSlotTap(def, equippedItems[def.slotKey]);
                  },
                  onLongPress: () {
                    if (isLocked) {
                      _showLockedSlotNotice(context, def);
                      return;
                    }
                    HapticFeedback.mediumImpact();
                    if (onSlotLongPress != null) {
                      onSlotLongPress!(def, equippedItems[def.slotKey]);
                    } else {
                      _showQuickComparisonTooltip(context, def, equippedItems[def.slotKey]);
                    }
                  },
                ),
              ),
            );
          }),
        ),

        // Right Radial Arc Column
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List<Widget>.generate(kRightEquipmentSlots.length, (int index) {
            final EquipmentSlotDef def = kRightEquipmentSlots[index];
            final bool isLocked = lockedSlotKeys?.contains(def.slotKey) ?? def.isLocked;
            final double curveOffset = _calculateRadialCurveOffset(
              index,
              kRightEquipmentSlots.length,
              isLeft: false,
            );

            return Padding(
              padding: EdgeInsets.symmetric(vertical: verticalSpacing),
              child: Transform.translate(
                offset: Offset(layout == EquipmentDockLayout.flanked ? 0.0 : curveOffset, 0),
                child: _EquipmentSocketButton(
                  slotDef: def,
                  item: equippedItems[def.slotKey],
                  size: effectiveSlotSize,
                  isHighlighted: highlightedSlotKey == def.slotKey,
                  isLocked: isLocked,
                  onTap: () {
                    if (isLocked) {
                      HapticFeedback.heavyImpact();
                      if (onLockedSlotTap != null) {
                        onLockedSlotTap!(def);
                      } else {
                        _showLockedSlotNotice(context, def);
                      }
                      return;
                    }
                    HapticFeedback.lightImpact();
                    onSlotTap(def, equippedItems[def.slotKey]);
                  },
                  onLongPress: () {
                    if (isLocked) {
                      _showLockedSlotNotice(context, def);
                      return;
                    }
                    HapticFeedback.mediumImpact();
                    if (onSlotLongPress != null) {
                      onSlotLongPress!(def, equippedItems[def.slotKey]);
                    } else {
                      _showQuickComparisonTooltip(context, def, equippedItems[def.slotKey]);
                    }
                  },
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Calculates parabolic curve offset to create celestial radial arch
  double _calculateRadialCurveOffset(int index, int total, {required bool isLeft}) {
    // Parabolic arc: center slots bulge slightly inward toward character
    final double normalized = (index / (total - 1)) * 2.0 - 1.0; // -1.0 to 1.0
    final double curveFactor = 1.0 - (normalized * normalized); // 0.0 at ends, 1.0 in center
    final double maxOffset = compact ? AppSpacing.sm : AppSpacing.md;
    final double offset = curveFactor * maxOffset;
    return isLeft ? offset : -offset;
  }

  void _showLockedSlotNotice(BuildContext context, EquipmentSlotDef def) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.spaceNavy.withValues(alpha: 0.95),
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          side: BorderSide(color: AppColors.borderBright.withValues(alpha: 0.4)),
        ),
        content: Row(
          children: <Widget>[
            const Icon(Icons.lock_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${def.name} yuvası Seviye ${def.unlockLevel ?? 10} gerektirir.',
                style: AppTextStyles.captionBold.copyWith(color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickComparisonTooltip(
    BuildContext context,
    EquipmentSlotDef def,
    InventoryItem? item,
  ) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: EquipmentQuickTooltip(slotDef: def, item: item),
      ),
    );
  }
}

/// Single Glowing Gear Socket with Ethereal Glow Shader, Aion 2 Rarity Frame,
/// Star Badges, Gem Insertion Indicators, and Lock State Support
class _EquipmentSocketButton extends StatefulWidget {
  const _EquipmentSocketButton({
    required this.slotDef,
    required this.item,
    required this.onTap,
    this.onLongPress,
    this.size = 50.0,
    this.isHighlighted = false,
    this.isLocked = false,
  });

  final EquipmentSlotDef slotDef;
  final InventoryItem? item;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double size;
  final bool isHighlighted;
  final bool isLocked;

  @override
  State<_EquipmentSocketButton> createState() => _EquipmentSocketButtonState();
}

class _EquipmentSocketButtonState extends State<_EquipmentSocketButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEquipped = widget.item != null;
    final int enhancementLevel = widget.item?.enhancementLevel ?? 0;
    final String rawRarity = widget.item?.rarity.name ?? 'common';
    final AionEquipmentRarity aionRarity = AionEquipmentRarity.fromRarityString(
      rawRarity,
      enhancementLevel: enhancementLevel,
    );
    final Color rarityColor =
        isEquipped ? aionRarity.primaryColor : Colors.white.withValues(alpha: 0.28);

    final String semanticsLabel = widget.isLocked
        ? '${widget.slotDef.name} Yuvası: Kilitli'
        : isEquipped
            ? '${widget.slotDef.name} Yuvası: ${widget.item!.name} (+${widget.item!.enhancementLevel})'
            : '${widget.slotDef.name} Yuvası: Boş, kuşanmak için dokunun';

    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Tooltip(
        message: widget.isLocked
            ? '${widget.slotDef.name} (Kilitli · Seviye ${widget.slotDef.unlockLevel ?? 10})'
            : isEquipped
                ? '${widget.item!.name} (+${widget.item!.enhancementLevel}) · ${aionRarity.displayName}'
                : '${widget.slotDef.name} (${widget.slotDef.subtitle ?? ""})',
        waitDuration: const Duration(milliseconds: 600),
        child: GestureDetector(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          behavior: HitTestBehavior.opaque,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (BuildContext context, Widget? child) {
              return CustomPaint(
                painter: AionRarityGlowPainter(
                  pulseValue: _pulseController.value,
                  rarity: aionRarity,
                  isEquipped: isEquipped,
                  isHighlighted: widget.isHighlighted,
                  enhancementLevel: enhancementLevel,
                  isLocked: widget.isLocked,
                ),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  alignment: Alignment.center,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      // 1. Watermark or Item Icon or Locked Padlock
                      if (widget.isLocked)
                        Icon(
                          Icons.lock_rounded,
                          size: widget.size * 0.38,
                          color: AppColors.mutedTitanium.withValues(alpha: 0.75),
                        )
                      else if (!isEquipped)
                        Opacity(
                          opacity: 0.35 + (_pulseController.value * 0.15),
                          child: Icon(
                            widget.slotDef.icon,
                            size: widget.size * 0.44,
                            color: Colors.white70,
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(5),
                          child: ItemIconView(
                            iconValue: widget.item!.icon,
                            itemId: widget.item!.itemId,
                            itemType: widget.item!.itemType,
                            size: widget.size * 0.62,
                            fit: BoxFit.contain,
                          ),
                        ),

                      // 2. Enhancement Star Badge (+X)
                      if (isEquipped && widget.item!.enhancementLevel > 0 && !widget.isLocked)
                        Positioned(
                          top: 1,
                          right: 1,
                          child: AionEnhancementBadge(
                            level: widget.item!.enhancementLevel,
                            rarityColor: aionRarity.primaryColor,
                          ),
                        ),

                      // 3. Gem Insertion Sockets indicator row (Manastone pips)
                      if (isEquipped && !widget.isLocked)
                        Positioned(
                          top: 2,
                          left: 3,
                          child: _buildGemSocketPips(widget.slotDef, widget.item!),
                        ),

                      // 4. Slot name badge at bottom
                      Positioned(
                        bottom: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(AppSpacing.xs),
                          ),
                          child: Text(
                            widget.isLocked ? 'Kilitli' : widget.slotDef.name,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              color: widget.isLocked
                                  ? AppColors.textTertiary
                                  : (isEquipped ? rarityColor : Colors.white38),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Compact gem socket indicator pips representing inserted elemental manastones
  Widget _buildGemSocketPips(EquipmentSlotDef def, InventoryItem item) {
    final int socketCount = math.min(def.maxGemSockets, 4);
    final int filledGems = math.min(
      socketCount,
      (item.enhancementLevel >= 10 ? socketCount : (item.enhancementLevel >= 5 ? 2 : 1)),
    );

    final List<Color> gemColors = <Color>[
      AppColors.mysticRuby,   // Attack / Crit Gem
      AppColors.accentBlue,   // Defense / Shield Gem
      AppColors.liquidGold,   // Power Gem
      AppColors.accentTeal,   // Vitality Gem
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(socketCount, (int i) {
        final bool isFilled = i < filledGems;
        final Color gemColor = isFilled ? gemColors[i % gemColors.length] : Colors.transparent;

        return Container(
          width: 3.5,
          height: 3.5,
          margin: const EdgeInsets.only(right: 1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: gemColor,
            border: Border.all(
              color: isFilled
                  ? gemColor.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.35),
              width: 0.5,
            ),
            boxShadow: isFilled
                ? <BoxShadow>[
                    BoxShadow(
                      color: gemColor.withValues(alpha: 0.7),
                      blurRadius: 2.5,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

/// CustomPainter rendering 2027 Aion 2 ethereal glow shader, metallic runic bevels,
/// celestial corner brackets, and TBDR GPU-optimized shaders.
class AionRarityGlowPainter extends CustomPainter {
  const AionRarityGlowPainter({
    required this.pulseValue,
    required this.rarity,
    required this.isEquipped,
    required this.isHighlighted,
    required this.enhancementLevel,
    this.isLocked = false,
  });

  final double pulseValue;
  final AionEquipmentRarity rarity;
  final bool isEquipped;
  final bool isHighlighted;
  final int enhancementLevel;
  final bool isLocked;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(13.0));

    // 1. Ethereal Outer Breathing Glow Shader
    if (!isLocked && (isEquipped || isHighlighted)) {
      final double glowSpread = isHighlighted ? 6.5 : (2.5 + pulseValue * 3.8);
      final double glowAlpha = (isHighlighted ? 0.65 : rarity.glowColor.a) *
          (0.75 + (pulseValue * 0.25));

      final Color baseGlowColor = isHighlighted ? AppColors.liquidGold : rarity.primaryColor;

      // Soft diffuse outer aura
      final Paint glowPaint = Paint()
        ..color = baseGlowColor.withValues(alpha: glowAlpha * 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSpread);
      canvas.drawRRect(rrect.inflate(1.5), glowPaint);

      // Inner concentrated neon halo
      final Paint coreHaloPaint = Paint()
        ..color = baseGlowColor.withValues(alpha: glowAlpha * 0.4)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSpread * 0.5);
      canvas.drawRRect(rrect.inflate(0.5), coreHaloPaint);
    }

    // 2. Base Dark Vignette Background
    final Paint bgPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topLeft,
        radius: 1.25,
        colors: isLocked
            ? <Color>[
                AppColors.spaceNavy.withValues(alpha: 0.88),
                AppColors.bgDeep.withValues(alpha: 0.98),
              ]
            : isEquipped
                ? <Color>[
                    AppColors.bgCardElevated.withValues(alpha: 0.95),
                    AppColors.bgDeep.withValues(alpha: 0.98),
                  ]
                : <Color>[
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.85),
                  ],
      ).createShader(rect);
    canvas.drawRRect(rrect, bgPaint);

    // 3. Metallic Chamfered Border with Breathing Rarity Gradient
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isEquipped ? 1.8 : 1.0
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isLocked
            ? <Color>[
                AppColors.borderDefault.withValues(alpha: 0.5),
                AppColors.borderFaint.withValues(alpha: 0.2),
              ]
            : isEquipped
                ? <Color>[
                    rarity.primaryColor.withValues(
                      alpha: 0.85 + (pulseValue * 0.15),
                    ),
                    rarity.secondaryColor.withValues(alpha: 0.65),
                  ]
                : <Color>[
                    Colors.white.withValues(alpha: 0.24),
                    Colors.white.withValues(alpha: 0.08),
                  ],
      ).createShader(rect);
    canvas.drawRRect(rrect, borderPaint);

    // 4. Aion 2 Celestial Corner Brackets & Rune Accents for High Tiers
    if (!isLocked &&
        isEquipped &&
        (rarity == AionEquipmentRarity.heroic ||
            rarity == AionEquipmentRarity.fabled ||
            rarity == AionEquipmentRarity.eternal ||
            enhancementLevel >= 7)) {
      final Paint accentPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = (rarity == AionEquipmentRarity.eternal
                ? AppColors.accentCyan
                : rarity.primaryColor)
            .withValues(alpha: 0.8 + (pulseValue * 0.2));

      // Top-Left corner bracket
      canvas.drawLine(const Offset(3, 8), const Offset(3, 3), accentPaint);
      canvas.drawLine(const Offset(3, 3), const Offset(8, 3), accentPaint);
      // Top-Right corner bracket
      canvas.drawLine(Offset(size.width - 8, 3), Offset(size.width - 3, 3), accentPaint);
      canvas.drawLine(Offset(size.width - 3, 3), Offset(size.width - 3, 8), accentPaint);
      // Bottom-Left corner bracket
      canvas.drawLine(Offset(3, size.height - 8), Offset(3, size.height - 3), accentPaint);
      canvas.drawLine(Offset(3, size.height - 3), Offset(8, size.height - 3), accentPaint);
      // Bottom-Right corner bracket
      canvas.drawLine(Offset(size.width - 8, size.height - 3), Offset(size.width - 3, size.height - 3), accentPaint);
      canvas.drawLine(Offset(size.width - 3, size.height - 8), Offset(size.width - 3, size.height - 3), accentPaint);

      // Celestial Cardinal Rune Tick Marks
      final Paint tickPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = accentPaint.color.withValues(alpha: 0.65);
      canvas.drawCircle(Offset(size.width / 2, 2.5), 1.0, tickPaint);
      canvas.drawCircle(Offset(size.width / 2, size.height - 2.5), 1.0, tickPaint);
      canvas.drawCircle(Offset(2.5, size.height / 2), 1.0, tickPaint);
      canvas.drawCircle(Offset(size.width - 2.5, size.height / 2), 1.0, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant AionRarityGlowPainter oldDelegate) {
    return oldDelegate.pulseValue != pulseValue ||
        oldDelegate.rarity != rarity ||
        oldDelegate.isEquipped != isEquipped ||
        oldDelegate.isHighlighted != isHighlighted ||
        oldDelegate.enhancementLevel != enhancementLevel ||
        oldDelegate.isLocked != isLocked;
  }
}

/// Enhancement Level Badge (+1 to +15) with Star Icons & Glowing Numerals
class AionEnhancementBadge extends StatelessWidget {
  const AionEnhancementBadge({
    super.key,
    required this.level,
    required this.rarityColor,
  });

  final int level;
  final Color rarityColor;

  @override
  Widget build(BuildContext context) {
    final bool isMax = level >= 15;
    final bool isHighTier = level >= 10;
    final bool isMidTier = level >= 5;

    final Color badgeBg = isMax
        ? AppColors.cyberFuchsia
        : (isHighTier ? AppColors.liquidGold : const Color(0xFFD97706));

    final int starCount = isMax ? 3 : (isHighTier ? 2 : (isMidTier ? 1 : 0));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 3.5, vertical: 1.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            badgeBg,
            badgeBg.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.7),
          width: 0.6,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: badgeBg.withValues(alpha: 0.65),
            blurRadius: 5,
            spreadRadius: 0.5,
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (starCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 1.5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List<Widget>.generate(starCount, (int i) {
                  return const Icon(
                    Icons.star_rounded,
                    size: 7.5,
                    color: Colors.black,
                  );
                }),
              ),
            ),
          // Crucial: Exact string format '+7', '+15' preserved for test assertion
          Text(
            '+$level',
            style: AppTextStyles.micro.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              height: 1.0,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating Quick Comparison Tooltip for Thumb-Friendly Long-Press Preview
class EquipmentQuickTooltip extends StatelessWidget {
  const EquipmentQuickTooltip({
    super.key,
    required this.slotDef,
    required this.item,
  });

  final EquipmentSlotDef slotDef;
  final InventoryItem? item;

  @override
  Widget build(BuildContext context) {
    final bool isEquipped = item != null;
    final AionEquipmentRarity rarity = isEquipped
        ? AionEquipmentRarity.fromRarityString(
            item!.rarity.name,
            enhancementLevel: item!.enhancementLevel,
          )
        : AionEquipmentRarity.common;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.spaceNavy.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isEquipped ? rarity.primaryColor : Colors.white24,
          width: 1.2,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: (isEquipped ? rarity.glowColor : Colors.black45),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: isEquipped
                  ? rarity.primaryColor.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              isEquipped ? Icons.shield_rounded : slotDef.icon,
              color: isEquipped ? rarity.primaryColor : Colors.white60,
              size: 26,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  isEquipped
                      ? '${item!.name} (+${item!.enhancementLevel})'
                      : '${slotDef.name} Yuvası Boş',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isEquipped ? rarity.primaryColor : Colors.white,
                  ),
                ),
                Text(
                  isEquipped
                      ? '${slotDef.name} · ${rarity.displayName}'
                      : 'Kuşanmak için yuvanın üzerine dokunun',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Colors.white70,
                  ),
                ),
                if (isEquipped && (item!.attack > 0 || item!.defense > 0)) ...<Widget>[
                  const SizedBox(height: 4),
                  Row(
                    children: <Widget>[
                      if (item!.attack > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            '+${item!.attack} ATK',
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 9.5,
                              color: AppColors.mysticRuby,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      if (item!.defense > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            '+${item!.defense} DEF',
                            style: AppTextStyles.micro.copyWith(
                              fontSize: 9.5,
                              color: AppColors.accentBlue,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      const Spacer(),
                      Text(
                        '◆◆◆◇ [Soket]',
                        style: AppTextStyles.micro.copyWith(
                          fontSize: 9,
                          color: AppColors.liquidGold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Modern Aion 2 Modal bottom sheet for inspecting, comparing, viewing gem sockets,
/// and unequipping gear.
class EquipmentDetailModal extends StatelessWidget {
  const EquipmentDetailModal({
    super.key,
    required this.slotDef,
    required this.item,
    required this.onUnequip,
  });

  final EquipmentSlotDef slotDef;
  final InventoryItem item;
  final VoidCallback onUnequip;

  @override
  Widget build(BuildContext context) {
    final String rarityStr = item.rarity.name;
    final AionEquipmentRarity aionRarity = AionEquipmentRarity.fromRarityString(
      rarityStr,
      enhancementLevel: item.enhancementLevel,
    );
    final Color rarityColor = aionRarity.primaryColor;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.base,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXxl)),
          border: Border.all(
            color: rarityColor.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.25),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Drag handle pill
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.base),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Item Header
            Row(
              children: <Widget>[
                Container(
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(color: rarityColor, width: 2),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: rarityColor.withValues(alpha: 0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: ItemIconView(
                    iconValue: item.icon,
                    itemId: item.itemId,
                    itemType: item.itemType,
                    size: 40,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.name,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: rarityColor,
                              ),
                            ),
                          ),
                          if (item.enhancementLevel > 0)
                            AionEnhancementBadge(
                              level: item.enhancementLevel,
                              rarityColor: rarityColor,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${slotDef.name} · ${aionRarity.displayName.toUpperCase()} (${rarityStr.toUpperCase()})',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Colors.white70,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.base),
            if (item.description.isNotEmpty) ...<Widget>[
              Text(
                item.description,
                style: AppTextStyles.caption.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Stats comparison chips row
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (item.attack > 0)
                  _statChip('Saldırı', '+${item.attack}', AppColors.mysticRuby, Icons.flash_on_rounded),
                if (item.defense > 0)
                  _statChip('Savunma', '+${item.defense}', AppColors.accentBlue, Icons.shield_rounded),
                if (item.health > 0)
                  _statChip('Can', '+${item.health}', AppColors.success, Icons.favorite_rounded),
                if (item.power > 0)
                  _statChip('Güç', '+${item.power}', AppColors.liquidGold, Icons.military_tech_rounded),
                if (item.luck > 0)
                  _statChip('Şans', '+${item.luck}', AppColors.cyberFuchsia, Icons.auto_awesome_rounded),
              ],
            ),

            const SizedBox(height: AppSpacing.base),

            // Manastone & Gem Insertion Sockets Section
            _buildManastoneSocketsSection(slotDef, item),

            const SizedBox(height: 20),

            // Actions: Close & Unequip Buttons
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Kapat'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.coralFlare,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).pop();
                      onUnequip();
                    },
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                    label: const Text('Kuşanı Çıkar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManastoneSocketsSection(EquipmentSlotDef def, InventoryItem item) {
    final int maxSockets = math.min(def.maxGemSockets, 4);
    final int filledSockets = math.min(
      maxSockets,
      (item.enhancementLevel >= 10 ? maxSockets : (item.enhancementLevel >= 5 ? 2 : 1)),
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: AppColors.liquidGold.withValues(alpha: 0.3),
          width: 1,
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
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: AppColors.liquidGold,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'MANASTONE VE MÜHÜR TAŞI YUVALARI',
                    style: AppTextStyles.micro.copyWith(
                      color: AppColors.liquidGold,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Text(
                '[$filledSockets / $maxSockets Yuva]',
                style: AppTextStyles.micro.copyWith(
                  color: filledSockets == maxSockets
                      ? AppColors.toxicNeon
                      : AppColors.mutedTitanium,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List<Widget>.generate(maxSockets, (int i) {
              final bool isFilled = i < filledSockets;
              final (String, Color, IconData) gemInfo = switch (i % 3) {
                0 => ('+18 Fiziksel Güç', AppColors.mysticRuby, Icons.diamond_rounded),
                1 => ('+24 Büyü Savunması', AppColors.accentBlue, Icons.shield_moon_rounded),
                _ => ('+15 Kritik Vuruş', AppColors.liquidGold, Icons.military_tech_rounded),
              };

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < maxSockets - 1 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isFilled
                        ? gemInfo.$2.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    border: Border.all(
                      color: isFilled
                          ? gemInfo.$2.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.18),
                      width: 0.8,
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Icon(
                        isFilled ? gemInfo.$3 : Icons.add_circle_outline_rounded,
                        size: 13,
                        color: isFilled ? gemInfo.$2 : Colors.white38,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isFilled ? 'Rün ${i + 1}' : 'Boş',
                        style: AppTextStyles.micro.copyWith(
                          fontSize: 8.5,
                          color: isFilled ? gemInfo.$2 : Colors.white38,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          // Crucial: Exact format '$label: $value' (e.g. 'Saldırı: +150') for tests
          Text(
            '$label: $value',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
