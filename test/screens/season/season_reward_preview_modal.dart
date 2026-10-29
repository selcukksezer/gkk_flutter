import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:gkk_flutter/screens/season/widgets/season_reward_illustrations.dart';
import 'package:gkk_flutter/theme/app_colors.dart';

/// 2027 Aion 2 Mobile Season Reward Preview Modal.
/// Displays an authentic high-tier reward illustration (Celestial Wings, Epic Weapon, etc.)
/// with celestial particle aura, rarity banner, level requirements, and inspect action.
class SeasonRewardPreviewModal extends StatelessWidget {
  const SeasonRewardPreviewModal({
    super.key,
    required this.rewardTitle,
    required this.illustrationType,
    required this.rarity,
    required this.requiredLevel,
    required this.isVipTrack,
    this.itemDescription = '2027 Sezon 1 seçkin ödülü. Daeva savaşçısının gücünü ve ihtişamını yansıtır.',
    this.statBonuses = const <String, String>{
      'Uçuş Hızı': '+15%',
      'PvP Saldırı Gücü': '+120',
      'Işık Direnci': '+85',
    },
    this.onClaim,
    this.isClaimable = false,
    this.isClaimed = false,
  });

  final String rewardTitle;
  final SeasonRewardIllustrationType illustrationType;
  final String rarity;
  final int requiredLevel;
  final bool isVipTrack;
  final String itemDescription;
  final Map<String, String> statBonuses;
  final VoidCallback? onClaim;
  final bool isClaimable;
  final bool isClaimed;

  /// Convenience helper to show modal via standard dialog.
  static Future<void> show(
    BuildContext context, {
    required String rewardTitle,
    required SeasonRewardIllustrationType illustrationType,
    required String rarity,
    required int requiredLevel,
    required bool isVipTrack,
    String? itemDescription,
    Map<String, String>? statBonuses,
    VoidCallback? onClaim,
    bool isClaimable = false,
    bool isClaimed = false,
  }) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (BuildContext ctx) => SeasonRewardPreviewModal(
        rewardTitle: rewardTitle,
        illustrationType: illustrationType,
        rarity: rarity,
        requiredLevel: requiredLevel,
        isVipTrack: isVipTrack,
        itemDescription: itemDescription ??
            '2027 Sezon 1 seçkin ödülü. Daeva savaşçısının gücünü ve ihtişamını yansıtır.',
        statBonuses: statBonuses ??
            const <String, String>{
              'Uçuş Hızı': '+15%',
              'PvP Saldırı Gücü': '+120',
              'Işık Direnci': '+85',
            },
        onClaim: onClaim,
        isClaimable: isClaimable,
        isClaimed: isClaimed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = AppColors.forRarity(rarity);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 350,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFA141926),
              Color(0xF50D111A),
              Color(0xFA070A10),
            ],
          ),
          border: Border.all(
            color: rarityColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.25),
              blurRadius: 28,
              spreadRadius: 2,
            ),
            const BoxShadow(
              color: Colors.black,
              blurRadius: 32,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Header with track badge and close button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: isVipTrack
                              ? AppColors.liquidGoldGradient
                              : const LinearGradient(
                                  colors: <Color>[Color(0xFF0284C7), AppColors.accentCyan],
                                ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              isVipTrack
                                  ? Icons.workspace_premium_rounded
                                  : Icons.shield_outlined,
                              size: 13,
                              color: isVipTrack ? AppColors.carbonVoid : Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isVipTrack ? 'DAEVA VIP ÖDÜLÜ' : 'SERBEST HAT ÖDÜLÜ',
                              style: TextStyle(
                                color: isVipTrack ? AppColors.carbonVoid : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                        onPressed: () => Navigator.of(context).maybePop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // High-tier Reward Illustration Display with Aura
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8,
                      colors: <Color>[
                        rarityColor.withValues(alpha: 0.22),
                        const Color(0x33000000),
                      ],
                    ),
                    border: Border.all(
                      color: rarityColor.withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Hero(
                      tag: 'season_reward_${illustrationType.name}',
                      child: SeasonRewardIllustrationView(
                        type: illustrationType,
                        size: 90,
                        rarity: rarity,
                        showGlow: true,
                      ),
                    ),
                  ),
                ),

              // Reward Title & Rarity Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: <Widget>[
                    Text(
                      rewardTitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.urbanist(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: rarityColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: rarityColor.withValues(alpha: 0.7)),
                          ),
                          child: Text(
                            rarity.toUpperCase(),
                            style: TextStyle(
                              color: rarityColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Text(
                            'SV $requiredLevel GEREKLİ',
                            style: const TextStyle(
                              color: Color(0xFFE2E8F0),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Item Description
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Text(
                  itemDescription,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),

              // Stat Bonuses Section
              if (statBonuses.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    children: statBonuses.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Text(
                              entry.key,
                              style: const TextStyle(
                                color: Color(0xFFCBD5E1),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              entry.value,
                              style: const TextStyle(
                                color: Color(0xFF4ADE80),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFCBD5E1),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'KAPAT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: isClaimed
                            ? null
                            : (isClaimable ? onClaim : () => Navigator.of(context).maybePop()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            gradient: isClaimed
                                ? null
                                : (isClaimable
                                    ? AppColors.liquidGoldGradient
                                    : const LinearGradient(
                                        colors: <Color>[Color(0xFF334155), Color(0xFF1E293B)],
                                      )),
                            color: isClaimed ? const Color(0x1F22C55E) : null,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isClaimed
                                  ? const Color(0xFF4ADE80)
                                  : (isClaimable
                                      ? AppColors.liquidGold
                                      : Colors.white.withValues(alpha: 0.2)),
                            ),
                            boxShadow: isClaimable
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.liquidGold.withValues(alpha: 0.35),
                                      blurRadius: 10,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Center(
                            child: Text(
                              isClaimed
                                  ? 'ALINDI'
                                  : (isClaimable ? 'ŞİMDİ AL' : 'İNCELE'),
                              style: TextStyle(
                                color: isClaimed
                                    ? const Color(0xFF4ADE80)
                                    : (isClaimable ? AppColors.carbonVoid : Colors.white),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                      ),
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
