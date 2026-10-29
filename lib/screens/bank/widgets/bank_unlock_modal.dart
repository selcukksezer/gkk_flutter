import 'dart:ui';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import 'bank_design.dart';

/// Aion 2 Royal Vault expansion dialog with frosted glass, ornate filigree,
/// and slot capacity visualizer.
class BankUnlockModal extends StatelessWidget {
  const BankUnlockModal({
    super.key,
    required this.currentSlots,
    required this.nextSlots,
    required this.gemCost,
  });

  final int currentSlots;
  final int nextSlots;
  final int gemCost;

  static Future<bool?> show(
    BuildContext context, {
    required int currentSlots,
    required int nextSlots,
    required int gemCost,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'BankUnlockModal',
      barrierColor: Colors.black.withValues(alpha: 0.75),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (BuildContext ctx, Animation<double> a1, Animation<double> a2) {
        return BankUnlockModal(
          currentSlots: currentSlots,
          nextSlots: nextSlots,
          gemCost: gemCost,
        );
      },
      transitionBuilder: (
        BuildContext ctx,
        Animation<double> anim,
        Animation<double> secondaryAnim,
        Widget child,
      ) {
        final CurvedAnimation curve = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final int slotDelta = (nextSlots - currentSlots) > 0 ? (nextSlots - currentSlots) : 1;
    final double capacityProgress = (nextSlots / bankMaxSlots).clamp(0.0, 1.0);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 348,
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xFF1E283C),
                        Color(0xFF121927),
                        Color(0xFF090D15),
                      ],
                      stops: <double>[0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: BankDesign.royalGoldFiligree.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: BankDesign.gold.withValues(alpha: 0.22),
                        blurRadius: 32,
                        spreadRadius: -2,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.65),
                        blurRadius: 28,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: <Widget>[
                      // Ambient golden radial sheen in top-right corner
                      Positioned(
                        top: -36,
                        right: -36,
                        child: IgnorePointer(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: <Color>[
                                  BankDesign.gold.withValues(alpha: 0.12),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Ambient celestial cyan radial sheen in bottom-left corner
                      Positioned(
                        bottom: -36,
                        left: -36,
                        child: IgnorePointer(
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: <Color>[
                                  BankDesign.crystalCyan.withValues(alpha: 0.08),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Scrollable content body ensuring 0 render overflow on any screen height/font scale
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            // Royal Vault Crest Emblem
                            Container(
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: <Color>[
                                    BankDesign.gold.withValues(alpha: 0.32),
                                    BankDesign.goldDim.withValues(alpha: 0.12),
                                  ],
                                ),
                                border: Border.all(
                                  color: BankDesign.royalGoldFiligree.withValues(alpha: 0.7),
                                  width: 1.6,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: BankDesign.gold.withValues(alpha: 0.35),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: <Widget>[
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: BankDesign.royalGoldGlint.withValues(alpha: 0.3),
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.lock_open_rounded,
                                    color: BankDesign.gold,
                                    size: 26,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Royal Header with gold filigree wings
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Container(
                                  width: 22,
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        Colors.transparent,
                                        BankDesign.royalGoldFiligree.withValues(alpha: 0.6),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Flexible(
                                  child: Text(
                                    'KRALİYET KASASI',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: BankDesign.gold,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 22,
                                  height: 1,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        BankDesign.royalGoldFiligree.withValues(alpha: 0.6),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Yeni Depolama Alanı Kilidini Aç',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.mutedTitanium,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Slot Capacity Transformation Card
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: BankDesign.royalObsidian.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: BankDesign.royalGoldFiligree.withValues(alpha: 0.25),
                                  width: 1.0,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      // Current Slot Column
                                      Expanded(
                                        child: Column(
                                          children: <Widget>[
                                            const Text(
                                              'MEVCUT',
                                              style: TextStyle(
                                                color: AppColors.mutedTitanium,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '$currentSlots',
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  fontFeatures: <FontFeature>[
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            const Text(
                                              'Slot Kapasitesi',
                                              style: TextStyle(
                                                color: Colors.white38,
                                                fontSize: 9.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Energy Transformation Catalyst
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: BoxDecoration(
                                          color: BankDesign.gold.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: BankDesign.royalGoldFiligree.withValues(alpha: 0.35),
                                            width: 1.0,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.arrow_forward_rounded,
                                          color: BankDesign.gold,
                                          size: 16,
                                        ),
                                      ),

                                      // Next Slot Column
                                      Expanded(
                                        child: Column(
                                          children: <Widget>[
                                            const Text(
                                              'HEDEF',
                                              style: TextStyle(
                                                color: BankDesign.goldLight,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 0.8,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                '$nextSlots',
                                                style: TextStyle(
                                                  color: BankDesign.gold,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  fontFeatures: const <FontFeature>[
                                                    FontFeature.tabularFigures(),
                                                  ],
                                                  shadows: <Shadow>[
                                                    Shadow(
                                                      color: BankDesign.gold.withValues(alpha: 0.35),
                                                      blurRadius: 10,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: BankDesign.crystalEmerald.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: BankDesign.crystalEmerald.withValues(alpha: 0.35),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                '+$slotDelta Slot',
                                                style: const TextStyle(
                                                  color: BankDesign.crystalEmerald,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 12),

                                  // Mini Vault Capacity Progress Bar
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.05),
                                      ),
                                    ),
                                    child: Column(
                                      children: <Widget>[
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: <Widget>[
                                            const Text(
                                              'Kasa İlerlemesi',
                                              style: TextStyle(
                                                color: AppColors.mutedTitanium,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            Text(
                                              '$nextSlots / $bankMaxSlots Max',
                                              style: const TextStyle(
                                                color: BankDesign.goldLight,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: LinearProgressIndicator(
                                            value: capacityProgress,
                                            minHeight: 5,
                                            backgroundColor: Colors.white.withValues(alpha: 0.08),
                                            valueColor: const AlwaysStoppedAnimation<Color>(
                                              BankDesign.gold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Gem Cost Banner
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: BankDesign.crystalCyan.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: BankDesign.crystalCyan.withValues(alpha: 0.4),
                                  width: 1.1,
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: BankDesign.crystalCyan.withValues(alpha: 0.15),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: BankDesign.crystalCyan.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.diamond_rounded,
                                      color: BankDesign.crystalCyan,
                                      size: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '$gemCost Elmas Harcanacak',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: BankDesign.crystalCyan,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Action Buttons
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: SizedBox(
                                    height: 44,
                                    child: TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.mutedTitanium,
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          side: BorderSide(
                                            color: Colors.white.withValues(alpha: 0.12),
                                          ),
                                        ),
                                      ),
                                      child: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          'Vazgeç',
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 2,
                                  child: SizedBox(
                                    height: 44,
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => Navigator.pop(context, true),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            gradient: BankDesign.royalGoldGradient,
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: <BoxShadow>[
                                              BoxShadow(
                                                color: BankDesign.gold.withValues(alpha: 0.4),
                                                blurRadius: 14,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: const Center(
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 10),
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: <Widget>[
                                                    Icon(
                                                      Icons.key_rounded,
                                                      color: AppColors.carbonVoid,
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 6),
                                                    Text(
                                                      'Slotu Aç',
                                                      maxLines: 1,
                                                      style: TextStyle(
                                                        color: AppColors.carbonVoid,
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 13.5,
                                                        letterSpacing: 0.6,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
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

                      // Top-Right Close Button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context, false),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.12),
                                ),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.mutedTitanium,
                              ),
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
      ),
    );
  }
}
