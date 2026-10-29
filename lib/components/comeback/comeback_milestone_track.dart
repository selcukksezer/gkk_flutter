import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'comeback_models.dart';
import 'comeback_particle_burst.dart';

/// 2027 Aion 2 Obsidian-Glass & Celestial Gold/Cyan Luminescence Palette
const Color _etherCyan = Color(0xFF00E5FF);
const Color _celestialGold = Color(0xFFE5C158);
const Color _solarGold = Color(0xFFFFD54F);
const Color _deepObsidian = Color(0xFF070B14);
const Color _surfaceObsidian = Color(0xFF0D1424);

/// 7-Day Returning Warrior Milestone Progression Track.
///
/// Upgraded to 2027 Aion 2 visual standard:
/// - Obsidian frosted glass container with dual [BackdropFilter] blur.
/// - Ether cyan (#00E5FF) energetic glowing progress line.
/// - Celestial gold (#E5C158) milestone node crystals.
/// - Distinct active, completed, and locked state luminescent styling.
/// - Tactile [HapticFeedback] integration with responsive [SafeArea] support.
class ComebackMilestoneTrack extends StatefulWidget {
  const ComebackMilestoneTrack({
    super.key,
    required this.tiers,
    this.currentDay = 1,
    this.onClaimTier,
  });

  final List<ComebackMilestoneTier> tiers;
  final int currentDay;
  final void Function(ComebackMilestoneTier tier)? onClaimTier;

  @override
  State<ComebackMilestoneTrack> createState() => _ComebackMilestoneTrackState();
}

class _ComebackMilestoneTrackState extends State<ComebackMilestoneTrack>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowCtrl;
  final ComebackParticleBurstController _burstCtrl =
      ComebackParticleBurstController();
  late List<ComebackMilestoneTier> _currentTiers;

  @override
  void initState() {
    super.initState();
    _currentTiers = List<ComebackMilestoneTier>.from(widget.tiers);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ComebackMilestoneTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tiers != oldWidget.tiers) {
      _currentTiers = List<ComebackMilestoneTier>.from(widget.tiers);
    }
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  void _claim(ComebackMilestoneTier tier) {
    if (!tier.isReady || tier.isClaimed) return;

    HapticFeedback.heavyImpact();
    _burstCtrl.burst(count: 45);

    setState(() {
      final int idx = _currentTiers.indexWhere((ComebackMilestoneTier t) => t.day == tier.day);
      if (idx != -1) {
        _currentTiers[idx] = tier.copyWith(isClaimed: true, isReady: false, isLocked: false);
      }
    });

    widget.onClaimTier?.call(tier);
  }

  void _inspectNode(ComebackMilestoneTier tier) {
    HapticFeedback.selectionClick();
    _showNodeInspectionSheet(context, tier);
  }

  int get _claimedCount => _currentTiers.where((ComebackMilestoneTier t) => t.isClaimed).length;

  double get _progressPercent {
    if (_currentTiers.isEmpty) return 0;
    return (_claimedCount / _currentTiers.length).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: ComebackParticleBurst(
        controller: _burstCtrl,
        child: AnimatedBuilder(
          animation: _glowCtrl,
          builder: (BuildContext context, Widget? child) {
            final double glow = _glowCtrl.value;
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        Color(0xF20B101E),
                        Color(0xEB060A14),
                        Color(0xF50E1528),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    border: Border.all(
                      color: Color.lerp(
                        _celestialGold.withValues(alpha: 0.38),
                        _etherCyan.withValues(alpha: 0.48),
                        glow * 0.4,
                      )!,
                      width: 1.2,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _celestialGold.withValues(alpha: 0.10 + 0.04 * glow),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: _etherCyan.withValues(alpha: 0.08 + 0.06 * glow),
                        blurRadius: 26,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _buildHeader(),
                      const SizedBox(height: 14),
                      _buildProgressBar(glow),
                      const SizedBox(height: 16),
                      _buildTiersCarousel(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                _celestialGold.withValues(alpha: 0.28),
                _etherCyan.withValues(alpha: 0.16),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _celestialGold.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _celestialGold.withValues(alpha: 0.25),
                blurRadius: 10,
              ),
            ],
          ),
          child: const Icon(
            Icons.flag_rounded,
            color: _celestialGold,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '7 Günlük Geri Dönüş Yolu',
                style: GoogleFonts.urbanist(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Her gün giriş yaparak kadim ödülleri topla',
                style: GoogleFonts.urbanist(
                  color: AppColors.mutedTitanium,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _deepObsidian.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _celestialGold.withValues(alpha: 0.45),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _celestialGold.withValues(alpha: 0.12),
                blurRadius: 8,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _etherCyan,
                  shape: BoxShape.circle,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _etherCyan.withValues(alpha: 0.8),
                      blurRadius: 5,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$_claimedCount / ${_currentTiers.length} Tamamlandı',
                style: GoogleFonts.urbanist(
                  color: _celestialGold,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double glow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Aion Enerji İlerlemesi',
              style: GoogleFonts.urbanist(
                color: AppColors.mutedTitanium,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
            Text(
              '${(_progressPercent * 100).toInt()}%',
              style: GoogleFonts.urbanist(
                color: _etherCyan,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 7,
            decoration: BoxDecoration(
              color: _deepObsidian.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _etherCyan.withValues(alpha: 0.2),
                width: 0.8,
              ),
            ),
            child: Stack(
              children: <Widget>[
                FractionallySizedBox(
                  widthFactor: _progressPercent,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          _etherCyan,
                          Color(0xFF00B4D8),
                          _celestialGold,
                          _solarGold,
                        ],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: _etherCyan.withValues(alpha: 0.7 + 0.2 * glow),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: _celestialGold.withValues(alpha: 0.4),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTiersCarousel() {
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _currentTiers.length,
        separatorBuilder: (_, __) => const SizedBox(width: 9),
        itemBuilder: (BuildContext context, int index) {
          final ComebackMilestoneTier tier = _currentTiers[index];
          return _MilestoneNodeCard(
            tier: tier,
            glowAnimation: _glowCtrl,
            onClaim: () => _claim(tier),
            onInspect: () => _inspectNode(tier),
          );
        },
      ),
    );
  }

  void _showNodeInspectionSheet(BuildContext context, ComebackMilestoneTier tier) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext ctx) {
        final Color rarityColor = tier.rarity.color;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Color(0xFA0F172B),
                        Color(0xF5080D18),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    border: Border.all(
                      color: _celestialGold.withValues(alpha: 0.5),
                      width: 1.4,
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: _celestialGold.withValues(alpha: 0.2),
                        blurRadius: 24,
                      ),
                      BoxShadow(
                        color: _etherCyan.withValues(alpha: 0.15),
                        blurRadius: 32,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // Top indicator handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.mutedTitanium.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(
                            Icons.diamond_rounded,
                            color: _celestialGold,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${tier.day}. Gün Aion Kristali',
                            style: GoogleFonts.urbanist(
                              color: _celestialGold,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Large Crystal Orb
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              _celestialGold.withValues(alpha: 0.35),
                              _etherCyan.withValues(alpha: 0.15),
                              _deepObsidian,
                            ],
                          ),
                          border: Border.all(
                            color: _celestialGold,
                            width: 2.0,
                          ),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: _celestialGold.withValues(alpha: 0.4),
                              blurRadius: 18,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          tier.rewardIcon,
                          color: _celestialGold,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Title
                      Text(
                        tier.title,
                        style: GoogleFonts.urbanist(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),

                      // Reward Amount & Rarity Pill
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: rarityColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: rarityColor.withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              tier.rarity.label,
                              style: TextStyle(
                                color: rarityColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tier.rewardAmount,
                            style: GoogleFonts.urbanist(
                              color: _etherCyan,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Description
                      Text(
                        tier.rewardDescription,
                        style: GoogleFonts.urbanist(
                          color: AppColors.mutedTitanium,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Bottom Action / Status
                      if (tier.isReady) ...<Widget>[
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(ctx).pop();
                              _claim(tier);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _celestialGold,
                              foregroundColor: _deepObsidian,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Icon(Icons.auto_awesome_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Ödülü Al',
                                  style: GoogleFonts.urbanist(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (tier.isClaimed) ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _deepObsidian,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _celestialGold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(
                                Icons.check_circle_rounded,
                                color: _celestialGold,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Bu kadim ödül başarıyla toplandı',
                                style: GoogleFonts.urbanist(
                                  color: AppColors.mutedTitanium,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...<Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: _deepObsidian,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _etherCyan.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.lock_rounded,
                                color: AppColors.mutedTitanium.withValues(alpha: 0.7),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${tier.day}. gün girişinde kilidi açılacak',
                                style: GoogleFonts.urbanist(
                                  color: AppColors.mutedTitanium,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MilestoneNodeCard extends StatelessWidget {
  const _MilestoneNodeCard({
    required this.tier,
    required this.glowAnimation,
    required this.onClaim,
    required this.onInspect,
  });

  final ComebackMilestoneTier tier;
  final Animation<double> glowAnimation;
  final VoidCallback onClaim;
  final VoidCallback onInspect;

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = tier.rarity.color;

    return AnimatedBuilder(
      animation: glowAnimation,
      builder: (BuildContext context, Widget? child) {
        final double glow = tier.isReady ? glowAnimation.value : 0.0;

        // Visual distinction per tier state: Active / Completed / Locked
        final Color cardBg;
        final Border cardBorder;
        final List<BoxShadow>? cardShadows;

        if (tier.isReady) {
          // Active state: radiant celestial gold & ether cyan luminescence
          cardBg = const Color(0xFF131D2E);
          cardBorder = Border.all(
            color: Color.lerp(
              _celestialGold,
              _etherCyan,
              (math.sin(glow * math.pi) + 1.0) * 0.35,
            )!,
            width: 1.5,
          );
          cardShadows = <BoxShadow>[
            BoxShadow(
              color: _celestialGold.withValues(alpha: 0.35 * glow + 0.22),
              blurRadius: 14,
              spreadRadius: 1.5,
            ),
            BoxShadow(
              color: _etherCyan.withValues(alpha: 0.25 * glow + 0.12),
              blurRadius: 10,
              spreadRadius: 0.5,
            ),
          ];
        } else if (tier.isClaimed) {
          // Completed state: sleek obsidian with subtle celestial gold halo
          cardBg = const Color(0xFF0C111C).withValues(alpha: 0.85);
          cardBorder = Border.all(
            color: _celestialGold.withValues(alpha: 0.32),
            width: 1.0,
          );
          cardShadows = <BoxShadow>[
            BoxShadow(
              color: _celestialGold.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ];
        } else {
          // Locked state: deep obsidian dusk with faint ether cyan runic border
          cardBg = _deepObsidian.withValues(alpha: 0.75);
          cardBorder = Border.all(
            color: _etherCyan.withValues(alpha: 0.16),
            width: 1.0,
          );
          cardShadows = null;
        }

        return GestureDetector(
          onTap: onInspect,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 108,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(14),
              border: cardBorder,
              boxShadow: cardShadows,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                // Top Day pill & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      '${tier.day}. Gün',
                      style: GoogleFonts.urbanist(
                        color: tier.isReady
                            ? _celestialGold
                            : (tier.isClaimed
                                ? AppColors.mutedTitanium
                                : AppColors.mutedTitanium.withValues(alpha: 0.7)),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (tier.isClaimed)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: _celestialGold,
                        size: 14,
                      )
                    else if (tier.isLocked)
                      Icon(
                        Icons.lock_rounded,
                        color: AppColors.mutedTitanium.withValues(alpha: 0.6),
                        size: 13,
                      )
                    else
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: _etherCyan,
                          shape: BoxShape.circle,
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: _etherCyan.withValues(alpha: 0.8),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),

                // Center Celestial Node Crystal
                _buildNodeCrystal(rarityColor, glow),

                // Label & Amount
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      tier.rewardAmount,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.urbanist(
                        color: tier.isClaimed
                            ? AppColors.mutedTitanium
                            : AppColors.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      tier.rarity.label,
                      style: TextStyle(
                        color: rarityColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                // Action button / status
                if (tier.isReady)
                  SizedBox(
                    width: double.infinity,
                    height: 25,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onClaim();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _celestialGold,
                        foregroundColor: _deepObsidian,
                        elevation: 4,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      child: Text(
                        'Al',
                        style: GoogleFonts.urbanist(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  )
                else if (tier.isClaimed)
                  Text(
                    'Alındı',
                    style: GoogleFonts.urbanist(
                      color: AppColors.mutedTitanium,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(
                    'Kilitli',
                    style: GoogleFonts.urbanist(
                      color: AppColors.mutedTitanium.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNodeCrystal(Color rarityColor, double glow) {
    final Color crystalBorderColor;
    final List<BoxShadow>? crystalGlow;

    if (tier.isReady) {
      crystalBorderColor = _celestialGold;
      crystalGlow = <BoxShadow>[
        BoxShadow(
          color: _celestialGold.withValues(alpha: 0.45 * glow + 0.25),
          blurRadius: 10,
          spreadRadius: 1,
        ),
        BoxShadow(
          color: _etherCyan.withValues(alpha: 0.3 * glow + 0.1),
          blurRadius: 8,
        ),
      ];
    } else if (tier.isClaimed) {
      crystalBorderColor = _celestialGold.withValues(alpha: 0.45);
      crystalGlow = null;
    } else {
      crystalBorderColor = _etherCyan.withValues(alpha: 0.2);
      crystalGlow = null;
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: <Color>[
            if (tier.isReady) ...<Color>[
              _celestialGold.withValues(alpha: 0.35),
              _surfaceObsidian,
            ] else if (tier.isClaimed) ...<Color>[
              _celestialGold.withValues(alpha: 0.15),
              _deepObsidian,
            ] else ...<Color>[
              _etherCyan.withValues(alpha: 0.08),
              _deepObsidian,
            ],
          ],
        ),
        border: Border.all(
          color: crystalBorderColor,
          width: tier.isReady ? 1.6 : 1.2,
        ),
        boxShadow: crystalGlow,
      ),
      child: Center(
        child: Icon(
          tier.rewardIcon,
          color: tier.isClaimed
              ? rarityColor.withValues(alpha: 0.55)
              : (tier.isReady ? _celestialGold : rarityColor.withValues(alpha: 0.8)),
          size: 23,
        ),
      ),
    );
  }
}
