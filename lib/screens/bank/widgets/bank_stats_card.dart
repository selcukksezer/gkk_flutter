import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'bank_design.dart';

/// Aion 2 Royal Vault Treasury overview card.
/// Features frosted glass depth, golden filigree accents, crystal stat tiles,
/// and responsive slot expansion trigger with overflow safety.
class BankStatsCard extends StatelessWidget {
  const BankStatsCard({
    super.key,
    required this.totalSlots,
    required this.usedSlots,
    required this.maxSlots,
    required this.expanding,
    required this.actionInProgress,
    required this.onExpand,
  });

  final int totalSlots;
  final int usedSlots;
  final int maxSlots;
  final bool expanding;
  final bool actionInProgress;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final int freeSlots = (totalSlots - usedSlots).clamp(0, maxSlots);
    final int lockedSlots = (maxSlots - totalSlots).clamp(0, maxSlots);
    final double fillPct = totalSlots > 0
        ? (usedSlots / totalSlots).clamp(0.0, 1.0)
        : 0.0;
    final bool canExpand = totalSlots < maxSlots;
    final int nextSlot = bankNextSlotIndex(totalSlots);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFA1E283C),
                  Color(0xF5121826),
                  Color(0xFA0A0E17),
                ],
                stops: <double>[0.0, 0.55, 1.0],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: BankDesign.royalGoldFiligree.withValues(alpha: 0.35),
                width: 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: BankDesign.gold.withValues(alpha: 0.10),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                const BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                // Specular top highlight glint
                Positioned(
                  top: 0,
                  left: 20,
                  right: 20,
                  height: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          BankDesign.royalGoldGlint.withValues(alpha: 0.6),
                          BankDesign.crystalCyan.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const <double>[0.0, 0.45, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      // Royal Vault Header with Crest & Status
                      Row(
                        children: <Widget>[
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: <Color>[
                                  BankDesign.gold.withValues(alpha: 0.30),
                                  BankDesign.goldDim.withValues(alpha: 0.12),
                                ],
                              ),
                              border: Border.all(
                                color: BankDesign.gold.withValues(alpha: 0.65),
                                width: 1.2,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: BankDesign.gold.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.account_balance_rounded,
                                color: BankDesign.gold,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'KRALİYET KASASI',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: BankDesign.gold,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Kadim Mühürlü Güvenli Hazine',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.mutedTitanium,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: BankDesign.crystalCyan.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: BankDesign.crystalCyan.withValues(alpha: 0.40),
                                width: 1,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: BankDesign.crystalCyan.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.verified_user_rounded,
                                  size: 11,
                                  color: BankDesign.crystalCyan,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Aktif Koruma',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: BankDesign.crystalCyan,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3 Crystal Stat Metrics
                      Row(
                        children: <Widget>[
                          _RoyalVaultStatTile(
                            label: 'Toplam Slot',
                            value: '$totalSlots',
                            icon: Icons.grid_on_rounded,
                            accentColor: BankDesign.gold,
                          ),
                          const SizedBox(width: 6),
                          _RoyalVaultStatTile(
                            label: 'Kullanılan',
                            value: '$usedSlots',
                            icon: Icons.inventory_2_rounded,
                            accentColor: BankDesign.crystalAmber,
                          ),
                          const SizedBox(width: 6),
                          _RoyalVaultStatTile(
                            label: 'Kullanılabilir',
                            value: '$freeSlots',
                            icon: Icons.check_circle_outline_rounded,
                            accentColor: BankDesign.crystalEmerald,
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Vault Capacity Bar & Slot Expansion Row
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: <Widget>[
                                    const Flexible(
                                      child: Text(
                                        'Kasa Doluluğu',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppColors.mutedTitanium,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '%${(fillPct * 100).round()}',
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: fillPct > 0.85
                                            ? BankDesign.withdraw
                                            : fillPct > 0.65
                                                ? BankDesign.crystalAmber
                                                : BankDesign.gold,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0A0E17),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.08),
                                        width: 1,
                                      ),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: fillPct,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: fillPct > 0.85
                                                ? const <Color>[
                                                    BankDesign.crystalRuby,
                                                    BankDesign.withdraw,
                                                  ]
                                                : fillPct > 0.65
                                                    ? const <Color>[
                                                        BankDesign.crystalAmber,
                                                        BankDesign.gold,
                                                      ]
                                                    : const <Color>[
                                                        BankDesign.goldDim,
                                                        BankDesign.gold,
                                                        BankDesign.royalGoldGlint,
                                                      ],
                                          ),
                                          borderRadius: BorderRadius.circular(6),
                                          boxShadow: <BoxShadow>[
                                            BoxShadow(
                                              color: (fillPct > 0.85
                                                      ? BankDesign.withdraw
                                                      : BankDesign.gold)
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 6,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (canExpand) ...<Widget>[
                                  const SizedBox(height: 6),
                                  Text(
                                    '$lockedSlots kilitli slot · $bankSlotUnlockCost 💎 / slot',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: BankDesign.gold.withValues(alpha: 0.85),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          if (canExpand)
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: (expanding || actionInProgress)
                                    ? null
                                    : onExpand,
                                borderRadius: BorderRadius.circular(12),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  constraints: const BoxConstraints(
                                    minWidth: 84,
                                    minHeight: 44,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: (expanding || actionInProgress)
                                        ? null
                                        : BankDesign.royalGoldGradient,
                                    color: (expanding || actionInProgress)
                                        ? const Color(0xFF18202E)
                                        : null,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: (expanding || actionInProgress)
                                          ? Colors.white.withValues(alpha: 0.12)
                                          : BankDesign.royalGoldFiligree,
                                      width: 1.2,
                                    ),
                                    boxShadow: (expanding || actionInProgress)
                                        ? null
                                        : <BoxShadow>[
                                            BoxShadow(
                                              color: BankDesign.gold.withValues(
                                                alpha: 0.35,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                  ),
                                  child: Center(
                                    child: expanding
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: BankDesign.gold,
                                            ),
                                          )
                                        : Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: <Widget>[
                                                  Icon(
                                                    Icons.add_rounded,
                                                    size: 14,
                                                    color: actionInProgress
                                                        ? AppColors.mutedTitanium
                                                        : AppColors.carbonVoid,
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Text(
                                                    'Slot Aç',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w900,
                                                      color: actionInProgress
                                                          ? AppColors.mutedTitanium
                                                          : AppColors.carbonVoid,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 1),
                                              FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Text(
                                                  '$bankSlotUnlockCost 💎 · #$nextSlot',
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w800,
                                                    color: actionInProgress
                                                        ? AppColors.mutedTitanium
                                                        : AppColors.carbonVoid
                                                            .withValues(alpha: 0.85),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Container(
                              constraints: const BoxConstraints(
                                minHeight: 44,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: BankDesign.gold.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: BankDesign.gold.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: BankDesign.gold.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    Icon(
                                      Icons.star_rounded,
                                      size: 14,
                                      color: BankDesign.gold,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Max Kapasite',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: BankDesign.gold,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoyalVaultStatTile extends StatelessWidget {
  const _RoyalVaultStatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accentColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              const Color(0xFF161F2E).withValues(alpha: 0.85),
              const Color(0xFF0C1019).withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.32),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 11,
                  color: accentColor.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.mutedTitanium,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: accentColor,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
