import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/item_icon_view.dart';
import '../../../core/services/app_haptics.dart';
import '../../../models/battle_pass.dart';
import '../../../theme/app_colors.dart';
import 'season_reward_illustrations.dart';

/// 2027 Aion 2 Mobile Dual-Tier Battle Pass Track Widget.
/// Renders Free Track (left) and Premium Daeva Track (right) connected by a central energy rail.
class SeasonTierTrackRow extends StatelessWidget {
  const SeasonTierTrackRow({
    super.key,
    required this.reward,
    required this.reached,
    required this.isCurrent,
    required this.claimedNormal,
    required this.claimedVip,
    required this.hasVip,
    required this.claimingFree,
    required this.claimingVip,
    required this.onClaimFree,
    required this.onClaimVip,
    this.isLast = false,
    this.onPreviewReward,
  });

  final BpLevelReward reward;
  final bool reached;
  final bool isCurrent;
  final bool claimedNormal;
  final bool claimedVip;
  final bool hasVip;
  final bool claimingFree;
  final bool claimingVip;
  final VoidCallback onClaimFree;
  final VoidCallback onClaimVip;
  final bool isLast;
  final void Function(BpLevelReward reward, bool isVip)? onPreviewReward;

  bool get isMilestone =>
      reward.level == 5 ||
      reward.level == 10 ||
      reward.level == 15 ||
      reward.level == 20 ||
      (reward.level > 0 && reward.level % 5 == 0);

  @override
  Widget build(BuildContext context) {
    final bool freeClaimable = reached && !claimedNormal;
    final bool vipClaimable = reached && hasVip && !claimedVip;
    final bool anyClaimable = freeClaimable || vipClaimable;
    final bool allClaimed = reached && claimedNormal && (!hasVip || claimedVip);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: reached
            ? (isMilestone ? const Color(0xF0181F30) : const Color(0xE6141A28))
            : const Color(0xB30E131E),
        border: Border.all(
          color: isCurrent
              ? AppColors.accentCyan.withValues(alpha: 0.90)
              : anyClaimable
                  ? AppColors.liquidGold.withValues(alpha: 0.85)
                  : isMilestone
                      ? AppColors.liquidGold.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.08),
          width: isCurrent ? 1.6 : (anyClaimable || isMilestone ? 1.3 : 0.9),
        ),
        boxShadow: <BoxShadow>[
          if (isCurrent)
            BoxShadow(
              color: AppColors.accentCyan.withValues(alpha: 0.30),
              blurRadius: 18,
              spreadRadius: 1,
            )
          else if (anyClaimable)
            BoxShadow(
              color: AppColors.liquidGold.withValues(alpha: 0.28),
              blurRadius: 16,
              spreadRadius: 1,
            )
          else if (isMilestone)
            BoxShadow(
              color: AppColors.liquidGold.withValues(alpha: 0.16),
              blurRadius: 12,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // ─── Milestone Header Banner (Only on Milestone Tiers) ─────────
            if (isMilestone)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      AppColors.liquidGold.withValues(alpha: 0.18),
                      AppColors.accentCyan.withValues(alpha: 0.08),
                      AppColors.liquidGold.withValues(alpha: 0.18),
                    ],
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.liquidGold.withValues(alpha: 0.35),
                      width: 0.8,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(Icons.stars_rounded,
                        size: 13, color: AppColors.liquidGold),
                    const SizedBox(width: 5),
                    Text(
                      'KİLOMETRE TAŞI • SEVİYE ${reward.level}',
                      style: GoogleFonts.urbanist(
                        color: AppColors.liquidGold,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(Icons.stars_rounded,
                        size: 13, color: AppColors.liquidGold),
                  ],
                ),
              ),

            // ─── Dual Track Row Content ──────────────────────────────────
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // ─── Free Track Reward (Left) ──────────────────────────
                  Expanded(
                    child: _TrackCell(
                      title: 'SERBEST HAT',
                      accentColor: AppColors.accentCyan,
                      gold: reward.normalRewardGold,
                      itemId: reward.normalRewardItemId,
                      item: reward.normalRewardItem,
                      quantity: reward.normalRewardQuantity,
                      level: reward.level,
                      isVipTrack: false,
                      reached: reached,
                      claimed: claimedNormal,
                      canClaim: freeClaimable,
                      claiming: claimingFree,
                      lockedByVip: false,
                      isMilestone: isMilestone,
                      onClaim: onClaimFree,
                      onPreview: onPreviewReward != null
                          ? () => onPreviewReward!(reward, false)
                          : null,
                    ),
                  ),

                  // ─── Central Energy Rail & Level Medallion (Animated) ───
                  _AnimatedMedallionRail(
                    level: reward.level,
                    reached: reached,
                    isCurrent: isCurrent,
                    isMilestone: isMilestone,
                    anyClaimable: anyClaimable,
                    allClaimed: allClaimed,
                    onTap: () {
                      AppHaptics.medium();
                      SeasonTierRewardPreviewModal.showTierOverview(
                        context,
                        reward: reward,
                        reached: reached,
                        claimedNormal: claimedNormal,
                        claimedVip: claimedVip,
                        hasVip: hasVip,
                        onClaimFree: onClaimFree,
                        onClaimVip: onClaimVip,
                      );
                    },
                  ),

                  // ─── Premium Daeva Track Reward (Right) ─────────────────
                  Expanded(
                    child: _TrackCell(
                      title: 'DAEVA VIP',
                      accentColor: AppColors.liquidGold,
                      gold: reward.vipRewardGold,
                      itemId: reward.vipRewardItemId,
                      item: reward.vipRewardItem,
                      quantity: reward.vipRewardQuantity,
                      level: reward.level,
                      isVipTrack: true,
                      reached: reached,
                      claimed: claimedVip,
                      canClaim: vipClaimable,
                      claiming: claimingVip,
                      lockedByVip: reached && !hasVip,
                      isMilestone: isMilestone,
                      onClaim: onClaimVip,
                      onPreview: onPreviewReward != null
                          ? () => onPreviewReward!(reward, true)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}

/// Animated Central Medallion Node with breathing energy rails and clean ticker lifecycle.
class _AnimatedMedallionRail extends StatefulWidget {
  const _AnimatedMedallionRail({
    required this.level,
    required this.reached,
    required this.isCurrent,
    required this.isMilestone,
    required this.anyClaimable,
    this.allClaimed = false,
    this.onTap,
  });

  final int level;
  final bool reached;
  final bool isCurrent;
  final bool isMilestone;
  final bool anyClaimable;
  final bool allClaimed;
  final VoidCallback? onTap;

  @override
  State<_AnimatedMedallionRail> createState() => _AnimatedMedallionRailState();
}

class _AnimatedMedallionRailState extends State<_AnimatedMedallionRail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (BuildContext context, Widget? child) {
        final double pulse = _pulseAnimation.value;
        final double scale = widget.isCurrent
            ? (1.0 + 0.05 * pulse)
            : (widget.anyClaimable ? (1.0 + 0.03 * pulse) : 1.0);
        final double nodeSize = widget.isMilestone ? 48.0 : 44.0;

        return SizedBox(
          width: 58,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              // Vertical Connecting Energy Rail Line
              Positioned(
                top: 0,
                bottom: 0,
                child: Container(
                  width: 2.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: widget.reached
                          ? <Color>[
                              AppColors.liquidGold.withValues(
                                  alpha: 0.8 + 0.2 * pulse),
                              AppColors.accentCyan.withValues(
                                  alpha: 0.8 + 0.2 * pulse),
                            ]
                          : <Color>[
                              Colors.white.withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                    ),
                    boxShadow: widget.reached
                        ? <BoxShadow>[
                            BoxShadow(
                              color: AppColors.accentCyan.withValues(
                                  alpha: 0.35 + 0.25 * pulse),
                              blurRadius: 6 + 3 * pulse,
                            ),
                          ]
                        : null,
                  ),
                ),
              ),

              // Central Medallion Node (Tappable for Milestone / Tier Overview)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  AppHaptics.medium();
                  widget.onTap?.call();
                },
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    width: nodeSize,
                    height: nodeSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: widget.isCurrent
                            ? const <Color>[
                                Color(0xFF0C2738),
                                Color(0xFF040F18),
                              ]
                            : widget.isMilestone
                                ? const <Color>[
                                    Color(0xFF38230B),
                                    Color(0xFF191106),
                                  ]
                                : widget.allClaimed
                                    ? const <Color>[
                                        Color(0xFF0A2219),
                                        Color(0xFF06140F),
                                      ]
                                    : widget.anyClaimable
                                        ? const <Color>[
                                            Color(0xFF281E0A),
                                            Color(0xFF120C03),
                                          ]
                                        : widget.reached
                                            ? const <Color>[
                                                Color(0xFF1E283C),
                                                Color(0xFF0E131E),
                                              ]
                                            : const <Color>[
                                                Color(0xFF141720),
                                                Color(0xFF0A0D14),
                                              ],
                      ),
                      border: Border.all(
                        color: widget.isCurrent
                            ? AppColors.accentCyan
                            : widget.isMilestone
                                ? AppColors.liquidGold
                                : widget.allClaimed
                                    ? const Color(0xFF4ADE80)
                                    : widget.anyClaimable
                                        ? AppColors.liquidGold
                                        : widget.reached
                                            ? AppColors.liquidGold.withValues(alpha: 0.6)
                                            : Colors.white.withValues(alpha: 0.15),
                        width: widget.isCurrent || widget.isMilestone ? 1.8 : 1.1,
                      ),
                      boxShadow: <BoxShadow>[
                        if (widget.isCurrent)
                          BoxShadow(
                            color: AppColors.accentCyan.withValues(
                                alpha: 0.35 + 0.30 * pulse),
                            blurRadius: 10 + 6 * pulse,
                            spreadRadius: 1 + pulse,
                          )
                        else if (widget.isMilestone)
                          BoxShadow(
                            color: AppColors.liquidGold.withValues(
                                alpha: 0.30 + 0.25 * pulse),
                            blurRadius: 10 + 6 * pulse,
                            spreadRadius: 1,
                          )
                        else if (widget.allClaimed)
                          BoxShadow(
                            color: const Color(0xFF4ADE80).withValues(alpha: 0.25),
                            blurRadius: 8,
                          )
                        else if (widget.anyClaimable)
                          BoxShadow(
                            color: AppColors.liquidGold.withValues(
                                alpha: 0.25 + 0.20 * pulse),
                            blurRadius: 8 + 4 * pulse,
                          ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          'SV',
                          style: TextStyle(
                            color: widget.isMilestone
                                ? AppColors.liquidGold
                                : widget.allClaimed
                                    ? const Color(0xFF4ADE80)
                                    : (widget.reached
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF475569)),
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          '${widget.level}',
                          style: GoogleFonts.urbanist(
                            color: widget.isCurrent
                                ? AppColors.accentCyan
                                : widget.isMilestone
                                    ? AppColors.liquidGold
                                    : widget.allClaimed
                                        ? const Color(0xFF4ADE80)
                                        : (widget.reached
                                            ? Colors.white
                                            : const Color(0xFF64748B)),
                            fontSize: widget.isMilestone ? 16 : 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Current tier marker pin
              if (widget.isCurrent)
                Positioned(
                  top: 2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.accentCyan.withValues(alpha: 0.5),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Text(
                      'BURADA',
                      style: TextStyle(
                        color: AppColors.carbonVoid,
                        fontSize: 6.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TrackCell extends StatelessWidget {
  const _TrackCell({
    required this.title,
    required this.accentColor,
    required this.gold,
    required this.itemId,
    required this.item,
    required this.quantity,
    required this.level,
    required this.isVipTrack,
    required this.reached,
    required this.claimed,
    required this.canClaim,
    required this.claiming,
    required this.lockedByVip,
    required this.isMilestone,
    required this.onClaim,
    this.onPreview,
  });

  final String title;
  final Color accentColor;
  final int gold;
  final String? itemId;
  final Map<String, dynamic>? item;
  final int quantity;
  final int level;
  final bool isVipTrack;
  final bool reached;
  final bool claimed;
  final bool canClaim;
  final bool claiming;
  final bool lockedByVip;
  final bool isMilestone;
  final VoidCallback onClaim;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final String? itemName = item?['name'] as String?;
    final String? itemIcon = item?['icon'] as String?;
    final String rarity = (item?['rarity'] as String?) ?? 'rare';
    final Color rarityColor = AppColors.forRarity(rarity);
    final bool hasContent = gold > 0 || itemId != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        AppHaptics.selection();
        if (onPreview != null) {
          onPreview!();
        } else if (hasContent) {
          SeasonTierRewardPreviewModal.showFromReward(
            context,
            level: level,
            isVipTrack: isVipTrack,
            itemId: itemId,
            item: item,
            gold: gold,
            quantity: quantity,
            isClaimable: canClaim,
            isClaimed: claimed,
            onClaim: onClaim,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isVipTrack
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: reached
                      ? <Color>[
                          const Color(0x38483112),
                          const Color(0x222A1C0A),
                          const Color(0x18181005),
                        ]
                      : <Color>[
                          const Color(0x1C281907),
                          const Color(0x0C140C04),
                        ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: reached
                      ? <Color>[
                          const Color(0x26102538),
                          const Color(0x160A1824),
                        ]
                      : <Color>[
                          const Color(0x100D1E2D),
                          const Color(0x08061118),
                        ],
                ),
          border: Border.all(
            color: isVipTrack
                ? (isMilestone
                    ? (reached
                        ? AppColors.liquidGold.withValues(alpha: 0.70)
                        : AppColors.liquidGold.withValues(alpha: 0.35))
                    : (reached
                        ? (canClaim
                            ? AppColors.liquidGold.withValues(alpha: 0.65)
                            : AppColors.liquidGold.withValues(alpha: 0.35))
                        : AppColors.liquidGold.withValues(alpha: 0.15)))
                : (reached
                    ? (canClaim
                        ? AppColors.accentCyan.withValues(alpha: 0.60)
                        : AppColors.accentCyan.withValues(alpha: 0.22))
                    : Colors.white.withValues(alpha: 0.05)),
            width: isMilestone && isVipTrack ? 1.2 : 0.8,
          ),
          boxShadow: <BoxShadow>[
            if (canClaim)
              BoxShadow(
                color: (isVipTrack ? AppColors.liquidGold : AppColors.accentCyan)
                    .withValues(alpha: 0.22),
                blurRadius: 8,
              )
            else if (isMilestone && reached)
              BoxShadow(
                color: (isVipTrack ? AppColors.liquidGold : AppColors.accentCyan)
                    .withValues(alpha: 0.12),
                blurRadius: 6,
              ),
          ],
        ),
        child: Opacity(
          opacity: reached ? 1.0 : 0.55,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Header tag (Fixed height: 18)
              SizedBox(
                height: 18,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (isVipTrack)
                      const Padding(
                        padding: EdgeInsets.only(right: 3),
                        child: Icon(Icons.workspace_premium_rounded,
                            size: 11, color: AppColors.liquidGold),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(right: 3),
                        child: Icon(Icons.shield_outlined,
                            size: 10.5,
                            color: accentColor.withValues(alpha: 0.85)),
                      ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 9,
                        color: isVipTrack ? AppColors.liquidGold : accentColor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Reward Visual (Fixed height: 68 for 100% collinear alignment)
              if (!hasContent)
                const SizedBox(
                  height: 68,
                  child: Center(
                    child: Text(
                      '—',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                    ),
                  ),
                )
              else
                _buildRewardVisual(itemName, itemIcon, rarityColor),

              const SizedBox(height: 8),

              // Action / Status Button (Fixed height: 28 for collinear alignment)
              SizedBox(
                height: 28,
                child: Center(
                  child: _buildClaimButton(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRewardVisual(
      String? itemName, String? itemIcon, Color rarityColor) {
    // Check if we should render a specialized 2027 illustration
    final bool useSpecialIllustration = isMilestone ||
        gold > 0 ||
        (itemName?.toLowerCase().contains('kanat') ?? false) ||
        (itemName?.toLowerCase().contains('sandık') ?? false) ||
        (itemName?.toLowerCase().contains('boya') ?? false) ||
        (itemName?.toLowerCase().contains('silah') ?? false);

    return SizedBox(
      height: 68,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: RadialGradient(
                colors: <Color>[
                  rarityColor.withValues(alpha: isMilestone ? 0.32 : 0.16),
                  Colors.transparent,
                ],
              ),
              border: Border.all(
                color: isMilestone
                    ? AppColors.liquidGold.withValues(alpha: 0.55)
                    : rarityColor.withValues(alpha: reached ? 0.35 : 0.15),
                width: isMilestone ? 1.1 : 0.7,
              ),
            ),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  useSpecialIllustration
                      ? SeasonRewardIllustrationView.fromReward(
                          level: level,
                          isVip: isVipTrack,
                          itemId: itemId,
                          item: item,
                          gold: gold,
                          size: 38,
                        )
                      : (itemId != null
                          ? ItemIconView(
                              itemId: itemId,
                              iconValue: itemIcon ?? '',
                              size: 36,
                            )
                          : SeasonRewardIllustrationView(
                              type: SeasonRewardIllustrationType.goldCache,
                              size: 36,
                              rarity: rarityColor.toString(),
                            )),
                  if (isMilestone)
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(1),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF261908),
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          size: 9,
                          color: AppColors.liquidGold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Text description (collinear baseline)
          SizedBox(
            height: 18,
            child: Center(
              child: gold > 0
                  ? Text(
                      '+$gold Altın',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4ADE80),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  : Text(
                      '${itemName ?? 'Eşya'} x$quantity',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isMilestone ? AppColors.liquidGold : rarityColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimButton(BuildContext context) {
    if (claimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x1F22C55E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0x6622C55E), width: 0.8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_circle_rounded,
                color: Color(0xFF4ADE80), size: 12),
            SizedBox(width: 3),
            Text(
              'ALINDI',
              style: TextStyle(
                color: Color(0xFF4ADE80),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    if (canClaim) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: claiming
            ? null
            : () {
                AppHaptics.medium();
                onClaim();
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            gradient: claiming ? null : AppColors.liquidGoldGradient,
            color: claiming ? const Color(0x44FFFFFF) : null,
            borderRadius: BorderRadius.circular(8),
            boxShadow: claiming
                ? null
                : <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.45),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: claiming
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.liquidGold,
                  ),
                )
              : Text(
                  isVipTrack ? 'DAEVA AL' : 'AL',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.carbonVoid,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      );
    }

    if (lockedByVip) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          AppHaptics.selection();
          SeasonTierRewardPreviewModal.showFromReward(
            context,
            level: level,
            isVipTrack: true,
            itemId: itemId,
            item: item,
            gold: gold,
            quantity: quantity,
            isClaimable: false,
            isClaimed: false,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
          decoration: BoxDecoration(
            color: const Color(0x26B8860B),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: AppColors.liquidGold.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.lock_outline_rounded,
                  size: 11, color: AppColors.liquidGold.withValues(alpha: 0.8)),
              const SizedBox(width: 3),
              Text(
                'VIP GEREKLİ',
                style: TextStyle(
                  color: AppColors.liquidGold.withValues(alpha: 0.9),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Default locked state
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.lock_rounded,
            color: Colors.white.withValues(alpha: 0.25), size: 13),
        const SizedBox(width: 3),
        Text(
          'KİLİTLİ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// 2027 Aion 2 Mobile High-Tier Season Reward Inspection Modal.
/// Frosted glass dialog with celestial particle aura, rarity banner, level requirements,
/// authentic stat bonuses, and claim actions.
class SeasonTierRewardPreviewModal extends StatelessWidget {
  const SeasonTierRewardPreviewModal({
    super.key,
    required this.rewardTitle,
    required this.illustrationType,
    required this.rarity,
    required this.requiredLevel,
    required this.isVipTrack,
    this.itemDescription =
        '2027 Sezon 1 seçkin ödülü. Daeva savaşçısının gücünü ve ihtişamını yansıtır.',
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

  /// Convenience static helper to show the preview modal via standard dialog.
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
    AppHaptics.medium();
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (BuildContext ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: SeasonTierRewardPreviewModal(
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
      ),
    );
  }

  /// Convenience helper to automatically infer preview details from raw reward data.
  static Future<void> showFromReward(
    BuildContext context, {
    required int level,
    required bool isVipTrack,
    String? itemId,
    Map<String, dynamic>? item,
    int gold = 0,
    int quantity = 1,
    String? customDescription,
    bool isClaimable = false,
    bool isClaimed = false,
    VoidCallback? onClaim,
  }) {
    final String? itemName = item?['name'] as String?;
    final String? itemDesc = item?['description'] as String?;
    final String rarity = (item?['rarity'] as String?) ??
        (level >= 20 ? 'mythic' : (level >= 15 ? 'legendary' : (level >= 5 ? 'epic' : 'rare')));

    final String title = gold > 0
        ? '$gold Altın'
        : (itemName != null ? '$itemName x$quantity' : 'Sezon $level Ödülü');

    final String description = customDescription ??
        itemDesc ??
        (gold > 0
            ? 'Krallık hazinesinden elde edilen sezon ilerleme altını.'
            : '2027 Daeva Battle Pass seçkin ödülü.');

    SeasonRewardIllustrationType type;
    if (level == 20 ||
        (itemName?.toLowerCase().contains('kanat') ?? false) ||
        (itemName?.toLowerCase().contains('wing') ?? false)) {
      type = SeasonRewardIllustrationType.celestialWings;
    } else if (level == 15 ||
        (itemName?.toLowerCase().contains('silah') ?? false) ||
        (itemName?.toLowerCase().contains('kılıç') ?? false) ||
        (itemName?.toLowerCase().contains('weapon') ?? false)) {
      type = SeasonRewardIllustrationType.epicWeaponSkin;
    } else if (level == 5 ||
        (itemName?.toLowerCase().contains('sandık') ?? false) ||
        (itemName?.toLowerCase().contains('kasa') ?? false) ||
        (itemName?.toLowerCase().contains('chest') ?? false)) {
      type = SeasonRewardIllustrationType.diamondChest;
    } else if (level == 10 ||
        (itemName?.toLowerCase().contains('boya') ?? false) ||
        (itemName?.toLowerCase().contains('ampul') ?? false) ||
        (itemName?.toLowerCase().contains('dye') ?? false)) {
      type = SeasonRewardIllustrationType.dyeAmpoule;
    } else if (gold > 0) {
      type = SeasonRewardIllustrationType.goldCache;
    } else {
      type = SeasonRewardIllustrationType.genericItem;
    }

    final Map<String, String> bonuses = <String, String>{};
    if (level == 20) {
      bonuses['Uçuş Hızı'] = '+25%';
      bonuses['Kutsal Işık Direnci'] = '+150';
      bonuses['Süzülme Süresi'] = 'Sınırsız';
    } else if (level == 15) {
      bonuses['Fiziksel Saldırı'] = '+95';
      bonuses['Kritik Vuruş Oranı'] = '+8%';
      bonuses['Saldırı Hızı'] = '+5%';
    } else if (gold > 0) {
      bonuses['Altın Kazancı'] = '+$gold';
    } else {
      bonuses['Miktar'] = 'x$quantity';
      bonuses['Kategori'] = isVipTrack ? 'Daeva VIP' : 'Serbest Hat';
    }

    return show(
      context,
      rewardTitle: title,
      illustrationType: type,
      rarity: rarity,
      requiredLevel: level,
      isVipTrack: isVipTrack,
      itemDescription: description,
      statBonuses: bonuses,
      onClaim: onClaim,
      isClaimable: isClaimable,
      isClaimed: isClaimed,
    );
  }

  /// Displays high-luxury dual-track tier overview popup for Free & Elite pass rewards.
  static Future<void> showTierOverview(
    BuildContext context, {
    required BpLevelReward reward,
    required bool reached,
    required bool claimedNormal,
    required bool claimedVip,
    required bool hasVip,
    required VoidCallback onClaimFree,
    required VoidCallback onClaimVip,
  }) {
    AppHaptics.medium();
    final bool isMilestone = reward.level == 5 ||
        reward.level == 10 ||
        reward.level == 15 ||
        reward.level == 20 ||
        (reward.level > 0 && reward.level % 5 == 0);

    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (BuildContext ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: 380,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  Color(0xFA161C2C),
                  Color(0xF50E131E),
                  Color(0xFA090D14),
                ],
              ),
              border: Border.all(
                color: isMilestone
                    ? AppColors.liquidGold.withValues(alpha: 0.75)
                    : AppColors.accentCyan.withValues(alpha: 0.5),
                width: isMilestone ? 1.8 : 1.2,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: (isMilestone
                          ? AppColors.liquidGold
                          : AppColors.accentCyan)
                      .withValues(alpha: 0.25),
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
                const BoxShadow(
                  color: Colors.black,
                  blurRadius: 36,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Header Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                      child: Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: isMilestone
                                  ? AppColors.liquidGoldGradient
                                  : const LinearGradient(
                                      colors: <Color>[
                                        Color(0xFF0284C7),
                                        AppColors.accentCyan
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  isMilestone
                                      ? Icons.stars_rounded
                                      : Icons.military_tech_rounded,
                                  size: 13,
                                  color: isMilestone
                                      ? AppColors.carbonVoid
                                      : Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'SEVİYE ${reward.level} ÖDÜLLERİ',
                                  style: TextStyle(
                                    color: isMilestone
                                        ? AppColors.carbonVoid
                                        : Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.7,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close_rounded,
                                color: Color(0xFF94A3B8), size: 20),
                            onPressed: () {
                              AppHaptics.selection();
                              Navigator.of(ctx).maybePop();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    // Milestone Banner description if milestone
                    if (isMilestone)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.liquidGold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.liquidGold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Row(
                          children: <Widget>[
                            Icon(Icons.workspace_premium_rounded,
                                size: 14, color: AppColors.liquidGold),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Bu seviye sezonun kilit dönüm noktasıdır! Seçkin ödüller içerir.',
                                style: TextStyle(
                                  color: AppColors.liquidGold,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Dual Track Cards Side-by-Side
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          // Free Track Card
                          Expanded(
                            child: _buildOverviewRewardCard(
                              ctx,
                              title: 'SERBEST HAT',
                              accentColor: AppColors.accentCyan,
                              isVip: false,
                              gold: reward.normalRewardGold,
                              itemId: reward.normalRewardItemId,
                              item: reward.normalRewardItem,
                              quantity: reward.normalRewardQuantity,
                              level: reward.level,
                              reached: reached,
                              claimed: claimedNormal,
                              canClaim: reached && !claimedNormal,
                              onClaim: onClaimFree,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Elite Track Card
                          Expanded(
                            child: _buildOverviewRewardCard(
                              ctx,
                              title: 'DAEVA VIP',
                              accentColor: AppColors.liquidGold,
                              isVip: true,
                              gold: reward.vipRewardGold,
                              itemId: reward.vipRewardItemId,
                              item: reward.vipRewardItem,
                              quantity: reward.vipRewardQuantity,
                              level: reward.level,
                              reached: reached,
                              claimed: claimedVip,
                              canClaim: reached && hasVip && !claimedVip,
                              lockedByVip: reached && !hasVip,
                              onClaim: onClaimVip,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Close Button
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            AppHaptics.selection();
                            Navigator.of(ctx).maybePop();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFCBD5E1),
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2)),
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildOverviewRewardCard(
    BuildContext context, {
    required String title,
    required Color accentColor,
    required bool isVip,
    required int gold,
    required String? itemId,
    required Map<String, dynamic>? item,
    required int quantity,
    required int level,
    required bool reached,
    required bool claimed,
    required bool canClaim,
    bool lockedByVip = false,
    required VoidCallback onClaim,
  }) {
    final String? itemName = item?['name'] as String?;
    final String rarity = (item?['rarity'] as String?) ?? 'rare';
    final Color rarityColor = AppColors.forRarity(rarity);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isVip
            ? const Color(0x223C270F)
            : const Color(0x22102538),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isVip
              ? AppColors.liquidGold.withValues(alpha: 0.5)
              : accentColor.withValues(alpha: 0.4),
          width: 1.0,
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (isVip)
                const Padding(
                  padding: EdgeInsets.only(right: 3),
                  child: Icon(Icons.workspace_premium_rounded,
                      size: 11, color: AppColors.liquidGold),
                ),
              Text(
                title,
                style: TextStyle(
                  color: isVip ? AppColors.liquidGold : accentColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SeasonRewardIllustrationView.fromReward(
            level: level,
            isVip: isVip,
            itemId: itemId,
            item: item,
            gold: gold,
            size: 44,
          ),
          const SizedBox(height: 6),
          Text(
            gold > 0
                ? '+$gold Altın'
                : '${itemName ?? 'Eşya'} x$quantity',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isVip ? AppColors.liquidGold : rarityColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (claimed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0x1F22C55E),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0x6622C55E), width: 0.8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.check_circle_rounded,
                      color: Color(0xFF4ADE80), size: 11),
                  SizedBox(width: 3),
                  Text(
                    'ALINDI',
                    style: TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else if (canClaim)
            GestureDetector(
              onTap: () {
                AppHaptics.success();
                Navigator.of(context).maybePop();
                onClaim();
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  gradient: AppColors.liquidGoldGradient,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: AppColors.liquidGold.withValues(alpha: 0.4),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  isVip ? 'DAEVA AL' : 'AL',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.carbonVoid,
                  ),
                ),
              ),
            )
          else if (lockedByVip)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0x26B8860B),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.liquidGold.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(Icons.lock_outline_rounded,
                      size: 10, color: AppColors.liquidGold),
                  SizedBox(width: 3),
                  Text(
                    'VIP GEREKLİ',
                    style: TextStyle(
                      color: AppColors.liquidGold,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            )
          else
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.lock_rounded,
                    color: Color(0x55FFFFFF), size: 11),
                SizedBox(width: 3),
                Text(
                  'KİLİTLİ',
                  style: TextStyle(
                    color: Color(0x66FFFFFF),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
        ],
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: isVipTrack
                              ? AppColors.liquidGoldGradient
                              : const LinearGradient(
                                  colors: <Color>[
                                    Color(0xFF0284C7),
                                    AppColors.accentCyan
                                  ],
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
                              color: isVipTrack
                                  ? AppColors.carbonVoid
                                  : Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isVipTrack
                                  ? 'DAEVA VIP ÖDÜLÜ'
                                  : 'SERBEST HAT ÖDÜLÜ',
                              style: TextStyle(
                                color: isVipTrack
                                    ? AppColors.carbonVoid
                                    : Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF94A3B8), size: 20),
                        onPressed: () {
                          AppHaptics.selection();
                          Navigator.of(context).maybePop();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // High-tier Reward Illustration Display with Aura
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                      tag: 'season_reward_${illustrationType.name}_$requiredLevel',
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: rarityColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: rarityColor.withValues(alpha: 0.7)),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15)),
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
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
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
                          onPressed: () {
                            AppHaptics.selection();
                            Navigator.of(context).maybePop();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFCBD5E1),
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2)),
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
                              : (isClaimable
                                  ? () {
                                      AppHaptics.success();
                                      Navigator.of(context).maybePop();
                                      onClaim?.call();
                                    }
                                  : () {
                                      AppHaptics.selection();
                                      Navigator.of(context).maybePop();
                                    }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              gradient: isClaimed
                                  ? null
                                  : (isClaimable
                                      ? AppColors.liquidGoldGradient
                                      : const LinearGradient(
                                          colors: <Color>[
                                            Color(0xFF334155),
                                            Color(0xFF1E293B)
                                          ],
                                        )),
                              color:
                                  isClaimed ? const Color(0x1F22C55E) : null,
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
                                        color: AppColors.liquidGold
                                            .withValues(alpha: 0.35),
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
                                      : (isClaimable
                                          ? AppColors.carbonVoid
                                          : Colors.white),
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

/// 2027 Aion 2 Mobile Responsive Horizontal Tier Track.
/// Renders horizontal swipeable dual-tier battle pass track with central glowing energy conduit.
/// Features automatic scroll controller lifecycle management (proper dispose), auto-scroll to current tier,
/// and pixel-perfect collinear reward alignment with tactile AppHaptics.
class SeasonHorizontalTierTrack extends StatefulWidget {
  const SeasonHorizontalTierTrack({
    super.key,
    required this.rewards,
    required this.currentLevel,
    required this.hasVip,
    required this.claimedNormal,
    required this.claimedVip,
    required this.claimingKeys,
    required this.onClaimFree,
    required this.onClaimVip,
    this.scrollController,
    this.onPreviewReward,
  });

  final List<BpLevelReward> rewards;
  final int currentLevel;
  final bool hasVip;
  final List<int> claimedNormal;
  final List<int> claimedVip;
  final Set<String> claimingKeys;
  final void Function(int level) onClaimFree;
  final void Function(int level) onClaimVip;
  final ScrollController? scrollController;
  final void Function(BpLevelReward reward, bool isVip)? onPreviewReward;

  @override
  State<SeasonHorizontalTierTrack> createState() =>
      _SeasonHorizontalTierTrackState();
}

class _SeasonHorizontalTierTrackState extends State<SeasonHorizontalTierTrack> {
  ScrollController? _internalController;
  ScrollController get _activeController =>
      widget.scrollController ?? _internalController!;

  static const double _columnWidth = 124.0;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController == null) {
      _internalController = ScrollController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToCurrent();
    });
  }

  @override
  void dispose() {
    // CRITICAL: Clean up internal scroll controller to prevent memory leaks
    _internalController?.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (!_activeController.hasClients || widget.currentLevel <= 1) return;
    final int index = widget.rewards
        .indexWhere((BpLevelReward r) => r.level == widget.currentLevel);
    if (index < 0) return;

    final double target = (index * _columnWidth)
        .clamp(0.0, _activeController.position.maxScrollExtent);

    _activeController.animateTo(
      target,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutQuint,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rewards.isEmpty) {
      return const SizedBox(
        height: 310,
        child: Center(
          child: Text(
            'Sezon ödülleri bulunamadı.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ),
      );
    }

    return SizedBox(
      height: 330,
      child: ListView.builder(
        controller: _activeController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: widget.rewards.length,
        itemBuilder: (BuildContext context, int index) {
          final BpLevelReward reward = widget.rewards[index];
          final int level = reward.level;
          final bool reached = widget.currentLevel >= level && level > 0;
          final bool isCurrent = widget.currentLevel == level;
          final bool claimedNormal = widget.claimedNormal.contains(level);
          final bool claimedVip = widget.claimedVip.contains(level);
          final bool freeClaimable = reached && !claimedNormal;
          final bool vipClaimable = reached && widget.hasVip && !claimedVip;
          final bool anyClaimable = freeClaimable || vipClaimable;
          final bool allClaimed =
              reached && claimedNormal && (!widget.hasVip || claimedVip);
          final bool isMilestone = level == 5 ||
              level == 10 ||
              level == 15 ||
              level == 20 ||
              (level > 0 && level % 5 == 0);

          return Container(
            width: _columnWidth,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: reached
                  ? (isMilestone
                      ? const Color(0xF2181E2E)
                      : const Color(0xE8141926))
                  : const Color(0xB50D111A),
              border: Border.all(
                color: isCurrent
                    ? AppColors.accentCyan.withValues(alpha: 0.90)
                    : anyClaimable
                        ? AppColors.liquidGold.withValues(alpha: 0.85)
                        : isMilestone
                            ? AppColors.liquidGold.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.08),
                width: isCurrent
                    ? 1.6
                    : (anyClaimable || isMilestone ? 1.3 : 0.9),
              ),
              boxShadow: <BoxShadow>[
                if (isCurrent)
                  BoxShadow(
                    color: AppColors.accentCyan.withValues(alpha: 0.28),
                    blurRadius: 16,
                    spreadRadius: 1,
                  )
                else if (anyClaimable)
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.22),
                    blurRadius: 14,
                  )
                else if (isMilestone)
                  BoxShadow(
                    color: AppColors.liquidGold.withValues(alpha: 0.14),
                    blurRadius: 10,
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: <Widget>[
                  // ─── Milestone Indicator Ribbon ─────────────────────────
                  if (isMilestone)
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            AppColors.liquidGold.withValues(alpha: 0.24),
                            AppColors.accentCyan.withValues(alpha: 0.12),
                            AppColors.liquidGold.withValues(alpha: 0.24),
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.liquidGold.withValues(alpha: 0.35),
                            width: 0.6,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(Icons.stars_rounded,
                              size: 10, color: AppColors.liquidGold),
                          const SizedBox(width: 3),
                          Text(
                            'DÖNÜM NOKTASI',
                            style: GoogleFonts.urbanist(
                              color: AppColors.liquidGold,
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ─── Top: Free Track Cell ──────────────────────────────
                  Expanded(
                    child: _TrackCell(
                      title: 'SERBEST',
                      accentColor: AppColors.accentCyan,
                      gold: reward.normalRewardGold,
                      itemId: reward.normalRewardItemId,
                      item: reward.normalRewardItem,
                      quantity: reward.normalRewardQuantity,
                      level: reward.level,
                      isVipTrack: false,
                      reached: reached,
                      claimed: claimedNormal,
                      canClaim: freeClaimable,
                      claiming: widget.claimingKeys.contains('r_${level}_free'),
                      lockedByVip: false,
                      isMilestone: isMilestone,
                      onClaim: () => widget.onClaimFree(level),
                      onPreview: widget.onPreviewReward != null
                          ? () => widget.onPreviewReward!(reward, false)
                          : null,
                    ),
                  ),

                  // ─── Center: Horizontal Connecting Level Conduit ───────────
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      AppHaptics.medium();
                      SeasonTierRewardPreviewModal.showTierOverview(
                        context,
                        reward: reward,
                        reached: reached,
                        claimedNormal: claimedNormal,
                        claimedVip: claimedVip,
                        hasVip: widget.hasVip,
                        onClaimFree: () => widget.onClaimFree(level),
                        onClaimVip: () => widget.onClaimVip(level),
                      );
                    },
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        border: Border.symmetric(
                          horizontal: BorderSide(
                            color: reached
                                ? (isMilestone
                                    ? AppColors.liquidGold.withValues(alpha: 0.5)
                                    : AppColors.liquidGold.withValues(alpha: 0.35))
                                : Colors.white.withValues(alpha: 0.06),
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: isCurrent
                                ? const LinearGradient(
                                    colors: <Color>[
                                      Color(0xFF0C2738),
                                      Color(0xFF040F18)
                                    ],
                                  )
                                : isMilestone
                                    ? const LinearGradient(
                                        colors: <Color>[
                                          Color(0xFF38230B),
                                          Color(0xFF191106)
                                        ],
                                      )
                                    : allClaimed
                                        ? const LinearGradient(
                                            colors: <Color>[
                                              Color(0xFF0A2219),
                                              Color(0xFF06140F)
                                            ],
                                          )
                                        : null,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isCurrent
                                  ? AppColors.accentCyan
                                  : isMilestone
                                      ? AppColors.liquidGold
                                      : allClaimed
                                          ? const Color(0xFF4ADE80)
                                          : anyClaimable
                                              ? AppColors.liquidGold
                                              : Colors.white.withValues(alpha: 0.15),
                              width: isCurrent || isMilestone ? 1.4 : 1.0,
                            ),
                            boxShadow: <BoxShadow>[
                              if (isCurrent)
                                BoxShadow(
                                  color: AppColors.accentCyan
                                      .withValues(alpha: 0.4),
                                  blurRadius: 8,
                                )
                              else if (anyClaimable || isMilestone)
                                BoxShadow(
                                  color: AppColors.liquidGold
                                      .withValues(alpha: 0.25),
                                  blurRadius: 6,
                                ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              if (allClaimed)
                                const Padding(
                                  padding: EdgeInsets.only(right: 3),
                                  child: Icon(Icons.check_rounded,
                                      size: 10, color: Color(0xFF4ADE80)),
                                ),
                              Text(
                                'SV ',
                                style: TextStyle(
                                  color: isMilestone
                                      ? AppColors.liquidGold
                                      : allClaimed
                                          ? const Color(0xFF4ADE80)
                                          : const Color(0xFF94A3B8),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '$level',
                                style: GoogleFonts.urbanist(
                                  color: isCurrent
                                      ? AppColors.accentCyan
                                      : isMilestone
                                          ? AppColors.liquidGold
                                          : allClaimed
                                              ? const Color(0xFF4ADE80)
                                              : Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ─── Bottom: Daeva VIP Cell ────────────────────────────
                  Expanded(
                    child: _TrackCell(
                      title: 'VIP',
                      accentColor: AppColors.liquidGold,
                      gold: reward.vipRewardGold,
                      itemId: reward.vipRewardItemId,
                      item: reward.vipRewardItem,
                      quantity: reward.vipRewardQuantity,
                      level: reward.level,
                      isVipTrack: true,
                      reached: reached,
                      claimed: claimedVip,
                      canClaim: vipClaimable,
                      claiming: widget.claimingKeys.contains('r_${level}_vip'),
                      lockedByVip: reached && !widget.hasVip,
                      isMilestone: isMilestone,
                      onClaim: () => widget.onClaimVip(level),
                      onPreview: widget.onPreviewReward != null
                          ? () => widget.onPreviewReward!(reward, true)
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// AAA Cyber-Fantasy Luxury Unified Season Pass Tier Track Component.
/// Provides a unified, highly polished dual-tier track with horizontal and vertical display modes,
/// milestone tracking, and seamless interactive reward previews.
class SeasonTierTrack extends StatelessWidget {
  const SeasonTierTrack({
    super.key,
    required this.rewards,
    required this.currentLevel,
    required this.hasVip,
    required this.claimedNormal,
    required this.claimedVip,
    required this.claimingKeys,
    required this.onClaimFree,
    required this.onClaimVip,
    this.scrollController,
    this.onPreviewReward,
    this.isHorizontal = true,
  });

  final List<BpLevelReward> rewards;
  final int currentLevel;
  final bool hasVip;
  final List<int> claimedNormal;
  final List<int> claimedVip;
  final Set<String> claimingKeys;
  final void Function(int level) onClaimFree;
  final void Function(int level) onClaimVip;
  final ScrollController? scrollController;
  final void Function(BpLevelReward reward, bool isVip)? onPreviewReward;
  final bool isHorizontal;

  @override
  Widget build(BuildContext context) {
    if (isHorizontal) {
      return SeasonHorizontalTierTrack(
        rewards: rewards,
        currentLevel: currentLevel,
        hasVip: hasVip,
        claimedNormal: claimedNormal,
        claimedVip: claimedVip,
        claimingKeys: claimingKeys,
        onClaimFree: onClaimFree,
        onClaimVip: onClaimVip,
        scrollController: scrollController,
        onPreviewReward: onPreviewReward,
      );
    }

    return ListView.builder(
      controller: scrollController,
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: rewards.length,
      itemBuilder: (BuildContext context, int index) {
        final BpLevelReward reward = rewards[index];
        final int level = reward.level;
        final bool reached = currentLevel >= level && level > 0;
        final bool isCurrent = currentLevel == level;
        final bool normalClaimed = claimedNormal.contains(level);
        final bool vipClaimed = claimedVip.contains(level);

        return SeasonTierTrackRow(
          reward: reward,
          reached: reached,
          isCurrent: isCurrent,
          claimedNormal: normalClaimed,
          claimedVip: vipClaimed,
          hasVip: hasVip,
          claimingFree: claimingKeys.contains('r_${level}_free'),
          claimingVip: claimingKeys.contains('r_${level}_vip'),
          onClaimFree: () => onClaimFree(level),
          onClaimVip: () => onClaimVip(level),
          isLast: index == rewards.length - 1,
          onPreviewReward: onPreviewReward,
        );
      },
    );
  }
}

