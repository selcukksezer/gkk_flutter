import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'bank_design.dart';

/// Luxury Aion 2 Crystal Tabs with faceted edges, specular highlights,
/// and luminous ambient aura.
class BankCrystalTabs extends StatelessWidget {
  const BankCrystalTabs({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    required this.vaultItemCount,
    required this.vaultTotalSlots,
    required this.inventoryItemCount,
    this.selectedCategory = 'all',
    this.onCategoryChanged,
  });

  final BankViewMode currentMode;
  final ValueChanged<BankViewMode> onModeChanged;
  final int vaultItemCount;
  final int vaultTotalSlots;
  final int inventoryItemCount;
  final String selectedCategory;
  final ValueChanged<String>? onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Primary Crystal View Mode Segmented Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: BankDesign.royalObsidian.withValues(alpha: 0.86),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[
                      const Color(0xFF161F2E).withValues(alpha: 0.90),
                      BankDesign.royalObsidian.withValues(alpha: 0.96),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: BankDesign.royalGoldFiligree.withValues(alpha: 0.28),
                    width: 1.2,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: BankDesign.royalGoldFiligree.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.50),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Stack(
                  children: <Widget>[
                    // Subtle crystal specular highlight line on top edge
                    Positioned(
                      top: 0,
                      left: 16,
                      right: 16,
                      height: 1,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Colors.transparent,
                              BankDesign.royalGoldGlint.withValues(alpha: 0.35),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Row(
                      children: <Widget>[
                        _CrystalTabItem(
                          mode: BankViewMode.transfer,
                          active: currentMode == BankViewMode.transfer,
                          title: 'Transfer',
                          icon: Icons.compare_arrows_rounded,
                          accentColor: BankDesign.crystalCyan,
                          badgeText: null,
                          onTap: () => onModeChanged(BankViewMode.transfer),
                        ),
                        const SizedBox(width: 4),
                        _CrystalTabItem(
                          mode: BankViewMode.vault,
                          active: currentMode == BankViewMode.vault,
                          title: 'Kasa',
                          icon: Icons.account_balance_rounded,
                          accentColor: BankDesign.gold,
                          badgeText: '$vaultItemCount/$vaultTotalSlots',
                          onTap: () => onModeChanged(BankViewMode.vault),
                        ),
                        const SizedBox(width: 4),
                        _CrystalTabItem(
                          mode: BankViewMode.inventory,
                          active: currentMode == BankViewMode.inventory,
                          title: 'Çanta',
                          icon: Icons.backpack_outlined,
                          accentColor: BankDesign.deposit,
                          badgeText: '$inventoryItemCount',
                          onTap: () => onModeChanged(BankViewMode.inventory),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (onCategoryChanged != null) ...<Widget>[
            const SizedBox(height: 8),
            _BankCategoryCrystalPills(
              selectedCategory: selectedCategory,
              onSelectCategory: onCategoryChanged!,
            ),
          ],
        ],
      ),
    );
  }
}

class _CrystalTabItem extends StatelessWidget {
  const _CrystalTabItem({
    required this.mode,
    required this.active,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.badgeText,
    required this.onTap,
  });

  final BankViewMode mode;
  final bool active;
  final String title;
  final IconData icon;
  final Color accentColor;
  final String? badgeText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: accentColor.withValues(alpha: 0.16),
          highlightColor: accentColor.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: active
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        accentColor.withValues(alpha: 0.32),
                        accentColor.withValues(alpha: 0.10),
                      ],
                    )
                  : LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.white.withValues(alpha: 0.035),
                        Colors.white.withValues(alpha: 0.01),
                      ],
                    ),
              border: Border.all(
                color: active
                    ? accentColor.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.08),
                width: active ? 1.2 : 0.8,
              ),
              boxShadow: active
                  ? <BoxShadow>[
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.28),
                        blurRadius: 12,
                        spreadRadius: 0.5,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.14),
                        blurRadius: 4,
                        offset: const Offset(0, -1),
                      ),
                    ]
                  : null,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool isCompact = constraints.maxWidth < 90;
                final double iconSize = isCompact ? 13.0 : 15.0;
                final double fontSize = isCompact ? 11.0 : 12.0;
                final double gap = isCompact ? 3.0 : 5.0;

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      icon,
                      size: iconSize,
                      color: active ? accentColor : AppColors.mutedTitanium,
                      shadows: active
                          ? <Shadow>[
                              Shadow(
                                color: accentColor.withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                    SizedBox(width: gap),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: active ? Colors.white : AppColors.mutedTitanium,
                          fontSize: fontSize,
                          fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    if (badgeText != null) ...<Widget>[
                      SizedBox(width: isCompact ? 2.0 : 4.0),
                      Flexible(
                        flex: 0,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 3.5 : 5.0,
                              vertical: 1.0,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? accentColor.withValues(alpha: 0.22)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: active
                                    ? accentColor.withValues(alpha: 0.6)
                                    : Colors.white.withValues(alpha: 0.12),
                                width: 0.8,
                              ),
                            ),
                            child: Text(
                              badgeText!,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: isCompact ? 8.5 : 9.5,
                                fontWeight: FontWeight.w700,
                                color: active ? accentColor : AppColors.textSecondary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _BankCategoryCrystalPills extends StatelessWidget {
  const _BankCategoryCrystalPills({
    required this.selectedCategory,
    required this.onSelectCategory,
  });

  final String selectedCategory;
  final ValueChanged<String> onSelectCategory;

  static const List<(String id, String label, IconData icon)> _categories = <(String, String, IconData)>[
    ('all', 'Tümü', Icons.grid_view_rounded),
    ('equipment', 'Teçhizat', Icons.shield_rounded),
    ('material', 'Materyal', Icons.diamond_rounded),
    ('consumable', 'Sarf', Icons.auto_fix_high_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        children: _categories.map(((String id, String label, IconData icon) cat) {
          final bool selected = selectedCategory == cat.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelectCategory(cat.$1),
                borderRadius: BorderRadius.circular(10),
                splashColor: BankDesign.gold.withValues(alpha: 0.16),
                highlightColor: BankDesign.gold.withValues(alpha: 0.08),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: selected
                        ? BankDesign.gold.withValues(alpha: 0.18)
                        : BankDesign.royalObsidian.withValues(alpha: 0.65),
                    gradient: selected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              BankDesign.gold.withValues(alpha: 0.28),
                              BankDesign.gold.withValues(alpha: 0.12),
                            ],
                          )
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[
                              Colors.white.withValues(alpha: 0.04),
                              BankDesign.royalObsidian.withValues(alpha: 0.65),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? BankDesign.royalGoldFiligree.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.09),
                      width: selected ? 1.1 : 0.8,
                    ),
                    boxShadow: selected
                        ? <BoxShadow>[
                            BoxShadow(
                              color: BankDesign.royalGoldFiligree.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        cat.$3,
                        size: 13,
                        color: selected ? BankDesign.goldLight : AppColors.mutedTitanium,
                        shadows: selected
                            ? <Shadow>[
                                Shadow(
                                  color: BankDesign.gold.withValues(alpha: 0.6),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        cat.$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected ? BankDesign.goldLight : AppColors.mutedTitanium,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
