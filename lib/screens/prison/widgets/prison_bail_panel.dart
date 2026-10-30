import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/system2_restriction_math.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. SENTENCE DURATION & REASON CARD (V3 AAA DARK IRON ELEVATION)
// ─────────────────────────────────────────────────────────────────────────────

/// Dark Fantasy Gothic Glass Card for Prison Sentence & Timer Display (V3 AAA).
/// Features dark iron rivets, glowing lock & chain aesthetics, dynamic bail countdown
/// timer with pulse animations, royal gold bounty badge, and Aion 2 slot framing.
class PrisonSentenceDurationCard extends StatefulWidget {
  const PrisonSentenceDurationCard({
    super.key,
    required this.countdown,
    required this.releaseLabel,
    required this.progress,
    required this.reasonLabel,
    required this.reasonValue,
    required this.remainingDuration,
    this.statusChip,
    this.crimeCategory,
    this.onTapCard,
  });

  final String countdown;
  final String releaseLabel;
  final double progress;
  final String reasonLabel;
  final String reasonValue;
  final Duration remainingDuration;
  final String? statusChip;
  final String? crimeCategory;
  final VoidCallback? onTapCard;

  @override
  State<PrisonSentenceDurationCard> createState() =>
      _PrisonSentenceDurationCardState();
}

class _PrisonSentenceDurationCardState extends State<PrisonSentenceDurationCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double clampedProgress = widget.progress.clamp(0.0, 1.0);
    final int percentInt = (clampedProgress * 100).toInt();
    final bool isNearRelease = widget.remainingDuration.inMinutes > 0 &&
        widget.remainingDuration.inMinutes <= 15;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xF20F1322),
                Color(0xF20B0E18),
                Color(0xF5070911),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: isNearRelease
                  ? AppColors.liquidGold.withValues(alpha: 0.65)
                  : AppColors.coralFlare.withValues(alpha: 0.45),
              width: 1.4,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.75),
                blurRadius: 22,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: isNearRelease
                    ? AppColors.liquidGold.withValues(alpha: 0.22)
                    : AppColors.coralFlare.withValues(alpha: 0.16),
                blurRadius: 28,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              // Decorative Gothic Iron Corner Rivets
              const Positioned(top: 8, left: 8, child: _GothicIronRivet()),
              const Positioned(top: 8, right: 8, child: _GothicIronRivet()),
              const Positioned(bottom: 8, left: 8, child: _GothicIronRivet()),
              const Positioned(bottom: 8, right: 8, child: _GothicIronRivet()),

              // Decorative Gothic Corner Brackets
              const Positioned(
                top: 4,
                left: 4,
                child: _GothicCornerBracket(isTop: true, isLeft: true),
              ),
              const Positioned(
                top: 4,
                right: 4,
                child: _GothicCornerBracket(isTop: true, isLeft: false),
              ),
              const Positioned(
                bottom: 4,
                left: 4,
                child: _GothicCornerBracket(isTop: false, isLeft: true),
              ),
              const Positioned(
                bottom: 4,
                right: 4,
                child: _GothicCornerBracket(isTop: false, isLeft: false),
              ),

              // Animated Glowing Iron Chain Header Links
              Positioned(
                top: 4,
                left: 40,
                right: 40,
                height: 10,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (BuildContext ctx, _) => CustomPaint(
                    painter: _GothicChainsPainter(
                      glowProgress: _pulseAnimation.value,
                    ),
                    size: const Size(double.infinity, 10),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // Crest & Reason Row with Gold Bounty Badge
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        // Iron Shackle Emblem with Aion 2 Action Slot Texture Framing
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                isNearRelease
                                    ? AppColors.liquidGold.withValues(alpha: 0.35)
                                    : AppColors.coralFlare.withValues(alpha: 0.35),
                                AppColors.carbonVoid.withValues(alpha: 0.9),
                              ],
                            ),
                            border: Border.all(
                              color: isNearRelease
                                  ? AppColors.liquidGold.withValues(alpha: 0.8)
                                  : AppColors.coralFlare.withValues(alpha: 0.6),
                              width: 1.4,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: (isNearRelease
                                        ? AppColors.liquidGold
                                        : AppColors.coralFlare)
                                    .withValues(alpha: 0.28),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              // Optional Aion 2 Slot Texture
                              Opacity(
                                opacity: 0.5,
                                child: Image.asset(
                                  'assets/images/aion2_ui/hud_action_bar_slot.png',
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              // Pulsing Lock & Chains Icon
                              AnimatedBuilder(
                                animation: _pulseAnimation,
                                builder: (BuildContext ctx, _) {
                                  final double scale =
                                      1.0 + _pulseAnimation.value * 0.08;
                                  return Transform.scale(
                                    scale: scale,
                                    child: Icon(
                                      isNearRelease
                                          ? Icons.lock_open_rounded
                                          : Icons.lock_rounded,
                                      size: 22,
                                      color: isNearRelease
                                          ? AppColors.liquidGold
                                          : AppColors.coralFlare,
                                      shadows: <Shadow>[
                                        Shadow(
                                          color: (isNearRelease
                                                  ? AppColors.liquidGold
                                                  : AppColors.coralFlare)
                                              .withValues(alpha: 0.8),
                                          blurRadius: 10,
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Text(
                                    'ZİNDAN CEZASI',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Imperial Gold Bounty Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: <Color>[
                                          Color(0xFF3B2A12),
                                          Color(0xFF1E1509),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusXs),
                                      border: Border.all(
                                        color: AppColors.liquidGold
                                            .withValues(alpha: 0.75),
                                        width: 0.9,
                                      ),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: AppColors.liquidGold
                                              .withValues(alpha: 0.25),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const <Widget>[
                                        Icon(
                                          Icons.shield_rounded,
                                          size: 10,
                                          color: AppColors.liquidGold,
                                        ),
                                        SizedBox(width: 3),
                                        Text(
                                          'FERMAN',
                                          style: TextStyle(
                                            color: AppColors.liquidGold,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (widget.statusChip != null) ...<Widget>[
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.mysticRuby
                                            .withValues(alpha: 0.22),
                                        borderRadius: BorderRadius.circular(
                                            AppSpacing.radiusXs),
                                        border: Border.all(
                                          color: AppColors.mysticRuby
                                              .withValues(alpha: 0.55),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        widget.statusChip!,
                                        style: const TextStyle(
                                          color: AppColors.coralFlare,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${widget.reasonLabel} ${widget.reasonValue}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.mutedTitanium,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Gothic Sentence Countdown Digit Display with Pulse Animation
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm + 2,
                        horizontal: AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF07090F).withValues(alpha: 0.88),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: isNearRelease
                              ? AppColors.liquidGold.withValues(alpha: 0.5)
                              : AppColors.coralFlare.withValues(alpha: 0.28),
                          width: 1.1,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: (isNearRelease
                                    ? AppColors.liquidGold
                                    : AppColors.coralFlare)
                                .withValues(alpha: 0.12),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Column(
                        children: <Widget>[
                          // Pulsing Dynamic Countdown Text
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (BuildContext ctx, _) {
                              final double p = _pulseAnimation.value;
                              final double scale =
                                  isNearRelease ? (1.0 + p * 0.035) : 1.0;
                              final Color textColor = isNearRelease
                                  ? AppColors.liquidGold
                                  : AppColors.coralFlare;
                              final double glowIntensity = isNearRelease
                                  ? (0.55 + p * 0.35)
                                  : (0.35 + p * 0.25);

                              return Transform.scale(
                                scale: scale,
                                child: Text(
                                  widget.countdown,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                    letterSpacing: 3.5,
                                    shadows: <Shadow>[
                                      Shadow(
                                        color: textColor.withValues(
                                          alpha: glowIntensity,
                                        ),
                                        blurRadius: isNearRelease ? 20 : 14,
                                      ),
                                      const Shadow(
                                        color: Colors.black,
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                    fontFeatures: const <FontFeature>[
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              const Icon(
                                Icons.access_time_filled_rounded,
                                size: 12,
                                color: AppColors.mutedTitanium,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Tahmini Tahliye: ${widget.releaseLabel}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Execution Progress Bar (Iron Track with Molten/Glow Fill)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text(
                              'Hüküm Süreci',
                              style: TextStyle(
                                color: AppColors.mutedTitanium,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              '%$percentInt Tamamlandı',
                              style: const TextStyle(
                                color: AppColors.liquidGold,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF06080E),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Stack(
                              children: <Widget>[
                                FractionallySizedBox(
                                  alignment: Alignment.centerLeft,
                                  widthFactor: clampedProgress,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: <Color>[
                                          AppColors.liquidGold,
                                          AppColors.coralFlare,
                                          AppColors.mysticRuby,
                                        ],
                                      ),
                                      boxShadow: <BoxShadow>[
                                        BoxShadow(
                                          color: AppColors.coralFlare
                                              .withValues(alpha: 0.6),
                                          blurRadius: 6,
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
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// 2. AAA PRISON BAIL ACTION CARD (CALCULATOR, SLIDER, QUICK PAY, COMPARISON)
// ─────────────────────────────────────────────────────────────────────────────

/// AAA Dark Gothic Glass Bail Action Card with Dynamic Slider,
/// Lawyer Fee Comparison Modal Launcher, and Bail Calculation Breakdown.
class PrisonBailActionCard extends StatefulWidget {
  const PrisonBailActionCard({
    super.key,
    required this.bailCost,
    required this.playerGems,
    required this.loading,
    required this.onPayBail,
    this.onGoToShop,
    this.wrap,
    this.remainingMinutes,
    this.playerGold,
    this.guardBribeCost,
    this.guildLawyerAvailable = true,
    this.onPayPartialBail,
    this.onOpenLawyerComparison,
    this.enablePartialPayment = true,
    this.showDetailedBreakdown = true,
  });

  final int bailCost;
  final num playerGems;
  final bool loading;
  final VoidCallback? onPayBail;
  final VoidCallback? onGoToShop;
  final Widget Function(Widget child)? wrap;

  /// Optional extended properties for AAA polish
  final int? remainingMinutes;
  final num? playerGold;
  final int? guardBribeCost;
  final bool guildLawyerAvailable;
  final void Function(int gemsToPay, int minutesReduced)? onPayPartialBail;
  final VoidCallback? onOpenLawyerComparison;
  final bool enablePartialPayment;
  final bool showDetailedBreakdown;

  @override
  State<PrisonBailActionCard> createState() => _PrisonBailActionCardState();
}

class _PrisonBailActionCardState extends State<PrisonBailActionCard>
    with SingleTickerProviderStateMixin {
  /// Payment ratio: 1.0 = Full Bail, 0.75 = 75%, 0.5 = 50%, 0.25 = 25%
  double _paymentRatio = 1.0;
  bool _showBreakdown = false;
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _glowAnimation = CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    );
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  int get _selectedGems {
    if (widget.bailCost <= 1) return widget.bailCost;
    if (_paymentRatio >= 0.99) return widget.bailCost;
    final int calculated = (widget.bailCost * _paymentRatio).ceil();
    return calculated.clamp(1, widget.bailCost);
  }

  int get _effectiveMinutesRemaining {
    if (widget.remainingMinutes != null && widget.remainingMinutes! > 0) {
      return widget.remainingMinutes!;
    }
    return math.max(1, widget.bailCost);
  }

  int get _minutesReduced {
    if (_paymentRatio >= 0.99) return _effectiveMinutesRemaining;
    final int reduced =
        (_effectiveMinutesRemaining * _paymentRatio).floor();
    return reduced.clamp(1, _effectiveMinutesRemaining);
  }

  void _handlePay() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    if (_paymentRatio >= 0.99) {
      widget.onPayBail?.call();
    } else {
      if (widget.onPayPartialBail != null) {
        widget.onPayPartialBail!(_selectedGems, _minutesReduced);
      } else {
        // Fallback to standard full bail callback if partial handler omitted
        widget.onPayBail?.call();
      }
    }
  }

  void _openLawyerComparison(BuildContext context) {
    if (!mounted) return;
    HapticFeedback.selectionClick();
    if (widget.onOpenLawyerComparison != null) {
      widget.onOpenLawyerComparison!();
    } else {
      PrisonGothicDialog.showLawyerFeeComparison(
        context,
        bailCost: widget.bailCost,
        playerGems: widget.playerGems,
        remainingMinutes: _effectiveMinutesRemaining,
        playerGold: widget.playerGold,
        guardBribeCost: widget.guardBribeCost,
        guildLawyerAvailable: widget.guildLawyerAvailable,
        onPayFullBail: widget.onPayBail,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final int costToPay = _selectedGems;
    final bool canAfford = widget.playerGems >= costToPay;
    final bool isPartial = _paymentRatio < 0.99;

    Widget buttonContent = AnimatedBuilder(
      animation: _glowAnimation,
      builder: (BuildContext ctx, Widget? childWidget) {
        final double glowP = _glowAnimation.value;
        return ElevatedButton(
          onPressed: (!widget.loading && canAfford) ? _handlePay : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: canAfford
                ? (isPartial ? AppColors.accentBlueDim : AppColors.coralFlare)
                : AppColors.bgCard,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                AppColors.darkObsidian.withValues(alpha: 0.5),
            disabledForegroundColor: AppColors.mutedTitanium,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              side: BorderSide(
                color: canAfford
                    ? (isPartial
                        ? AppColors.accentBlue.withValues(alpha: 0.6)
                        : AppColors.liquidGold
                            .withValues(alpha: 0.5 + glowP * 0.35))
                    : Colors.white.withValues(alpha: 0.08),
                width: 1.3,
              ),
            ),
            elevation: canAfford ? 6 : 0,
            shadowColor: isPartial
                ? AppColors.accentBlue.withValues(alpha: 0.5)
                : AppColors.coralFlare.withValues(alpha: 0.35 + glowP * 0.4),
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(
                      isPartial
                          ? Icons.hourglass_bottom_rounded
                          : Icons.key_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPartial
                          ? 'Kısmi İndirim Öde ($costToPay 💎 → −$_minutesReduced Dk)'
                          : 'Kefalet Öde ($costToPay Elmas)',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        );
      },
    );

    if (widget.wrap != null) {
      buttonContent = widget.wrap!(buttonContent);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xF20F1322),
                Color(0xF20B0E18),
                Color(0xF5070911),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: canAfford
                  ? AppColors.liquidGold.withValues(alpha: 0.45)
                  : AppColors.mysticRuby.withValues(alpha: 0.45),
              width: 1.3,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: canAfford
                    ? AppColors.liquidGold.withValues(alpha: 0.10)
                    : AppColors.mysticRuby.withValues(alpha: 0.10),
                blurRadius: 20,
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              // Decorative Gothic Iron Rivets
              const Positioned(top: 6, left: 6, child: _GothicIronRivet()),
              const Positioned(top: 6, right: 6, child: _GothicIronRivet()),
              const Positioned(bottom: 6, left: 6, child: _GothicIronRivet()),
              const Positioned(bottom: 6, right: 6, child: _GothicIronRivet()),

              // Decorative Corner Brackets
              const Positioned(
                top: 3,
                left: 3,
                child: _GothicCornerBracket(isTop: true, isLeft: true),
              ),
              const Positioned(
                top: 3,
                right: 3,
                child: _GothicCornerBracket(isTop: true, isLeft: false),
              ),

              Padding(
                padding: const EdgeInsets.all(AppSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // Header Info Row with Aion 2 Slot Texture Framing
                    Row(
                      children: <Widget>[
                        // Gem Currency Slot Container
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(
                              color:
                                  AppColors.accentPurple.withValues(alpha: 0.55),
                              width: 1.2,
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: AppColors.accentPurple
                                    .withValues(alpha: 0.25),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              Opacity(
                                opacity: 0.65,
                                child: Image.asset(
                                  'assets/images/aion2_ui/hud_action_bar_slot.png',
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              const Text('💎', style: TextStyle(fontSize: 19)),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Text(
                                    'Kefalet ile Erken Tahliye',
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Gold Legal Ferman Badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.liquidGold
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(
                                          AppSpacing.radiusXs),
                                      border: Border.all(
                                        color: AppColors.liquidGold
                                            .withValues(alpha: 0.5),
                                        width: 0.7,
                                      ),
                                    ),
                                    child: const Text(
                                      'YASAL',
                                      style: TextStyle(
                                        color: AppColors.liquidGold,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Mevcut Kasa: ${(widget.playerGems % 1 == 0) ? widget.playerGems.toInt() : widget.playerGems} Elmas',
                                style: TextStyle(
                                  color: canAfford
                                      ? AppColors.accentTeal
                                      : AppColors.mysticRuby,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: canAfford
                                ? AppColors.accentTeal.withValues(alpha: 0.15)
                                : AppColors.mysticRuby.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(
                              color: canAfford
                                  ? AppColors.accentTeal.withValues(alpha: 0.45)
                                  : AppColors.mysticRuby.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            canAfford ? 'Ödenebilir' : 'Yetersiz',
                            style: TextStyle(
                              color: canAfford
                                  ? AppColors.accentTeal
                                  : AppColors.mysticRuby,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.sm + 4),

                    // Interactive Slider for Partial/Full Bail
                    if (widget.enablePartialPayment && widget.bailCost > 1) ...<Widget>[
                      PrisonPartialPaymentSlider(
                        ratio: _paymentRatio,
                        totalBailCost: widget.bailCost,
                        totalMinutes: _effectiveMinutesRemaining,
                        onChanged: (double val) {
                          if (!mounted) return;
                          setState(() => _paymentRatio = val);
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],

                    // Bail Action Button
                    buttonContent,

                    const SizedBox(height: AppSpacing.sm),

                    // Bottom Control Row: Breakdown Toggle & Lawyer Comparison Modal Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        // Breakdown Accordion Button
                        if (widget.showDetailedBreakdown)
                          InkWell(
                            onTap: () {
                              if (!mounted) return;
                              HapticFeedback.selectionClick();
                              setState(() => _showBreakdown = !_showBreakdown);
                            },
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    _showBreakdown
                                        ? Icons.keyboard_arrow_up_rounded
                                        : Icons.calculate_outlined,
                                    size: 14,
                                    color: AppColors.mutedTitanium,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _showBreakdown
                                        ? 'Hesabı Gizle'
                                        : 'Kefalet Hesabı',
                                    style: const TextStyle(
                                      color: AppColors.mutedTitanium,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          const SizedBox.shrink(),

                        // Lawyer Comparison Matrix Button
                        InkWell(
                          onTap: () => _openLawyerComparison(context),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusSm),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 6,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const <Widget>[
                                Icon(
                                  Icons.gavel_rounded,
                                  size: 13,
                                  color: AppColors.accentCyan,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Avukat Seçenekleri ⚖️',
                                  style: TextStyle(
                                    color: AppColors.accentCyan,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Animated Bail Breakdown Ledger
                    if (_showBreakdown) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      PrisonBailCalculationPanel(
                        remainingMinutes: _effectiveMinutesRemaining,
                        gemCost: widget.bailCost,
                      ),
                    ],

                    // Insufficient Balance & Shop CTA
                    if (!canAfford) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      InkWell(
                        onTap: () {
                          if (!mounted) return;
                          HapticFeedback.selectionClick();
                          if (widget.onGoToShop != null) {
                            widget.onGoToShop!();
                          } else {
                            context.go('/shop');
                          }
                        },
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mysticRuby.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusSm),
                            border: Border.all(
                              color: AppColors.mysticRuby.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const <Widget>[
                              Icon(
                                Icons.shopping_bag_outlined,
                                size: 14,
                                color: AppColors.liquidGold,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Elmas Satın Al → Dükkana Git',
                                style: TextStyle(
                                  color: AppColors.liquidGold,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. BAIL CALCULATION BREAKDOWN PANEL
// ─────────────────────────────────────────────────────────────────────────────

/// Gothic Parchment/Ledger Breakdown Panel detailing how the bail is calculated.
/// Elevated with Aion 2 parchment box background and dark iron framing.
class PrisonBailCalculationPanel extends StatelessWidget {
  const PrisonBailCalculationPanel({
    super.key,
    required this.remainingMinutes,
    required this.gemCost,
    this.baseRatePerMinute = 1.0,
    this.courtTaxGems = 0,
    this.guildDiscountPercent = 0,
  });

  final int remainingMinutes;
  final int gemCost;
  final double baseRatePerMinute;
  final int courtTaxGems;
  final int guildDiscountPercent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xF4080B14),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          border: Border.all(
            color: AppColors.liquidGold.withValues(alpha: 0.32),
            width: 1.1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: <Widget>[
            // Aion 2 Dialogue Parchment Box Backdrop Overlay
            Positioned.fill(
              child: Opacity(
                opacity: 0.12,
                child: Image.asset(
                  'assets/images/aion2_ui/hud_dialogue_parchment_box.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: const <Widget>[
                      Icon(
                        Icons.balance_rounded,
                        size: 14,
                        color: AppColors.liquidGold,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Zindan Mahkeme Tarifesi',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0x22FFFFFF)),
                  const SizedBox(height: 8),

                  _ledgerRow('Kalan Süre', '$remainingMinutes dakika'),
                  _ledgerRow('Temel Oran', '1 💎 / 1 dk'),
                  _ledgerRow(
                    'Yargı Harcı',
                    courtTaxGems > 0 ? '+$courtTaxGems 💎' : 'Muaf',
                  ),
                  if (guildDiscountPercent > 0)
                    _ledgerRow(
                      'Lonca İndirimi',
                      '−%$guildDiscountPercent',
                      valueColor: AppColors.accentTeal,
                    ),

                  const SizedBox(height: 6),
                  const Divider(height: 1, color: Color(0x33FFFFFF)),
                  const SizedBox(height: 6),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const Text(
                        'Nihai Kefalet Bedeli:',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '$gemCost 💎',
                        style: const TextStyle(
                          color: AppColors.liquidGold,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
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
    );
  }

  Widget _ledgerRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: AppColors.mutedTitanium,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              fontFeatures: const <FontFeature>[
                FontFeature.tabularFigures(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. PARTIAL PAYMENT SLIDER & PRESET CHIPS
// ─────────────────────────────────────────────────────────────────────────────

/// High-tech Gothic Slider allowing inmate to pay custom partial bail amounts.
class PrisonPartialPaymentSlider extends StatelessWidget {
  const PrisonPartialPaymentSlider({
    super.key,
    required this.ratio,
    required this.totalBailCost,
    required this.totalMinutes,
    required this.onChanged,
  });

  final double ratio;
  final int totalBailCost;
  final int totalMinutes;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final int currentGems = (totalBailCost * ratio).ceil().clamp(1, totalBailCost);
    final int minutesCut = (totalMinutes * ratio).floor().clamp(1, totalMinutes);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF070A12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Value & Summary Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              const Text(
                'Ödeme Miktarı:',
                style: TextStyle(
                  color: AppColors.mutedTitanium,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$currentGems 💎 (−$minutesCut dk)',
                style: TextStyle(
                  color: ratio >= 0.99
                      ? AppColors.liquidGold
                      : AppColors.accentBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          // Custom Dark Gothic Slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: ratio >= 0.99
                  ? AppColors.coralFlare
                  : AppColors.accentBlue,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: ratio >= 0.99
                  ? AppColors.liquidGold
                  : AppColors.accentBlue,
              overlayColor: (ratio >= 0.99
                      ? AppColors.coralFlare
                      : AppColors.accentBlue)
                  .withValues(alpha: 0.2),
              trackHeight: 3.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
            ),
            child: Slider(
              value: ratio.clamp(0.25, 1.0),
              min: 0.25,
              max: 1.0,
              divisions: 15,
              onChanged: (double val) {
                HapticFeedback.selectionClick();
                onChanged(val);
              },
            ),
          ),

          // Preset Ratio Quick Chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _presetChip('25%', 0.25),
              _presetChip('50%', 0.50),
              _presetChip('75%', 0.75),
              _presetChip('100% (Tam)', 1.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _presetChip(String label, double presetRatio) {
    final bool isSelected = (ratio - presetRatio).abs() < 0.05;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(presetRatio);
      },
      borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? (presetRatio >= 0.99
                  ? AppColors.coralFlare.withValues(alpha: 0.25)
                  : AppColors.accentBlue.withValues(alpha: 0.25))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
          border: Border.all(
            color: isSelected
                ? (presetRatio >= 0.99
                    ? AppColors.coralFlare
                    : AppColors.accentBlue)
                : Colors.white.withValues(alpha: 0.1),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? AppColors.textPrimary
                : AppColors.mutedTitanium,
            fontSize: 9,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. LAWYER FEE & RELEASE OPTION COMPARISON PANEL
// ─────────────────────────────────────────────────────────────────────────────

/// Detailed Comparison Card / Matrix for Legal Counsel, Bail, and Bribes.
class PrisonLawyerFeeComparisonPanel extends StatelessWidget {
  const PrisonLawyerFeeComparisonPanel({
    super.key,
    required this.bailCost,
    required this.playerGems,
    required this.remainingMinutes,
    this.playerGold,
    this.guardBribeCost,
    this.guildLawyerAvailable = true,
    this.onPayFullBail,
  });

  final int bailCost;
  final num playerGems;
  final int remainingMinutes;
  final num? playerGold;
  final int? guardBribeCost;
  final bool guildLawyerAvailable;
  final VoidCallback? onPayFullBail;

  @override
  Widget build(BuildContext context) {
    final int bribeGold = guardBribeCost ??
        System2RestrictionMath.prisonGuardBribeCost(remainingMinutes);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF40A0D17),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: AppColors.accentCyan.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.gavel_rounded,
                  color: AppColors.accentCyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Hukuki Savunma & Tahliye Kıyaslaması',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Kefalet, avukat ve alternatif tahliye yolları',
                      style: TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // 1. Direct Bail Card
          _comparisonOptionCard(
            title: 'Nakit Kefalet (Doğrudan Tahliye)',
            badge: 'Anında Özgürlük',
            costText: '$bailCost Elmas 💎',
            speedText: 'Anlık (0 sn)',
            effectText: '%100 Tahliye — Derhal serbest kalırsın.',
            riskText: 'Risk Yok (%100 Başarı)',
            accent: AppColors.coralFlare,
            icon: Icons.key_rounded,
          ),

          const SizedBox(height: AppSpacing.sm),

          // 2. Guild Lawyer Card
          _comparisonOptionCard(
            title: 'Lonca Hukuk Savunması',
            badge: guildLawyerAvailable ? 'Kullanılabilir' : 'Bekleme Süresi',
            costText: 'Ücretsiz (Lonca Fonu)',
            speedText: 'Hızlı İtiraz',
            effectText: 'Hüküm süresinde önemli indirim sağlar.',
            riskText: 'Yalnızca aktif lonca üyeleri',
            accent: AppColors.accentCyan,
            icon: Icons.shield_outlined,
          ),

          const SizedBox(height: AppSpacing.sm),

          // 3. Guard Negotiation (Bribe)
          _comparisonOptionCard(
            title: 'Gardiyan Uzlaşması (Gayriresmi)',
            badge: 'Gizli Anlaşma',
            costText: '$bribeGold Altın 🪙',
            speedText: 'Hemen İnceleme',
            effectText: '%20 Süre İndirimi (10–60 dk arası kısaltma)',
            riskText: '%45–%60 Başarı — Başarısız olursa altın yanar',
            accent: AppColors.liquidGold,
            icon: Icons.handshake_outlined,
          ),

          const SizedBox(height: AppSpacing.sm),

          // 4. Bar Association Criminal Lawyer (Informational Lore)
          _comparisonOptionCard(
            title: 'Bağımsız Ağır Ceza Avukatı',
            badge: 'Resmi Başvuru',
            costText: '150.000 Altın 🪙',
            speedText: 'Duruşma Sonrası',
            effectText: 'Sabıka temizliği + Kısmi süre tahliyesi',
            riskText: 'Yüksek mahkeme masrafı gerektirir',
            accent: AppColors.accentPurple,
            icon: Icons.account_balance_outlined,
          ),
        ],
      ),
    );
  }

  Widget _comparisonOptionCard({
    required String title,
    required String badge,
    required String costText,
    required String speedText,
    required String effectText,
    required String riskText,
    required Color accent,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: const Color(0xFF07090F),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: accent.withValues(alpha: 0.3),
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
                  Icon(icon, size: 14, color: accent),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Text(
                'Maliyet: ',
                style: const TextStyle(
                  color: AppColors.mutedTitanium,
                  fontSize: 10,
                ),
              ),
              Text(
                costText,
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                'Hız: $speedText',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            effectText,
            style: const TextStyle(
              color: AppColors.mutedTitanium,
              fontSize: 10,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '⚠️ $riskText',
            style: const TextStyle(
              color: AppColors.textTertiary,
              fontSize: 9,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. RICH FEEDBACK ALERT BANNER
// ─────────────────────────────────────────────────────────────────────────────

enum PrisonAlertType { info, success, warning, danger, gothic }

/// Dark Glassmorphic Alert for legal status, bail notifications, and warnings.
class PrisonFeedbackAlert extends StatelessWidget {
  const PrisonFeedbackAlert({
    super.key,
    required this.message,
    this.title,
    this.type = PrisonAlertType.info,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final String? title;
  final PrisonAlertType type;
  final String? actionLabel;
  final VoidCallback? onAction;

  Color get _accentColor => switch (type) {
        PrisonAlertType.info => AppColors.accentBlue,
        PrisonAlertType.success => AppColors.accentTeal,
        PrisonAlertType.warning => AppColors.liquidGold,
        PrisonAlertType.danger => AppColors.mysticRuby,
        PrisonAlertType.gothic => AppColors.coralFlare,
      };

  IconData get _icon => switch (type) {
        PrisonAlertType.info => Icons.info_outline_rounded,
        PrisonAlertType.success => Icons.check_circle_outline_rounded,
        PrisonAlertType.warning => Icons.warning_amber_rounded,
        PrisonAlertType.danger => Icons.error_outline_rounded,
        PrisonAlertType.gothic => Icons.shield_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: _accentColor.withValues(alpha: 0.38),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(_icon, color: _accentColor, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(
                    title!,
                    style: TextStyle(
                      color: _accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (actionLabel != null && onAction != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onAction!();
              },
              style: TextButton.styleFrom(
                foregroundColor: _accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. INMATE ACTION BENTO TILE
// ─────────────────────────────────────────────────────────────────────────────

/// Dark Gothic Glass Bento Action Tile for labor, bribery, lawyer, and escape.
class PrisonLaborActionTile extends StatelessWidget {
  const PrisonLaborActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.badge,
    this.loading = false,
    this.wrap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final String? badge;
  final bool loading;
  final Widget Function(Widget child)? wrap;

  @override
  Widget build(BuildContext context) {
    Widget content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading
            ? null
            : () {
                HapticFeedback.lightImpact();
                onTap?.call();
              },
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xF2101422),
                Color(0xF00C0F19),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: accent.withValues(alpha: 0.38),
              width: 1.2,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.10),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              // Top Row: Aion 2 Slot-Framed Icon + Optional Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.5),
                        width: 1.1,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.18),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Opacity(
                          opacity: 0.6,
                          child: Image.asset(
                            'assets/images/aion2_ui/hud_action_bar_slot.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        Icon(icon, color: accent, size: 18),
                      ],
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.18),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusXs),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.4),
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        badge!,
                        style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Title and Subtitle
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              if (loading) ...<Widget>[
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: accent,
                    backgroundColor: accent.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (wrap != null) {
      content = wrap!(content);
    }

    return content;
  }
}

/// Dark Gothic Frosted Glass Dialogs for Bail, Insufficient Gems, Lawyer Comparison, and Bribes.
abstract final class PrisonGothicDialog {
  /// Dark Gothic Bail Confirmation Dialog with cost breakdown.
  static Future<bool?> showBailConfirm(
    BuildContext context, {
    required int bailCost,
    required num playerGems,
    int? remainingMinutes,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        final num remainingBalance = playerGems - bailCost;
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xF20F1320),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: AppColors.coralFlare.withValues(alpha: 0.45),
                  width: 1.4,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                  BoxShadow(
                    color: AppColors.coralFlare.withValues(alpha: 0.15),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Header Icon with Aion 2 Slot Framing
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.coralFlare.withValues(alpha: 0.15),
                      border: Border.all(
                        color: AppColors.coralFlare.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.coralFlare.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Opacity(
                          opacity: 0.6,
                          child: Image.asset(
                            'assets/images/aion2_ui/hud_action_bar_slot.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        const Icon(
                          Icons.key_rounded,
                          color: AppColors.coralFlare,
                          size: 26,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Title
                  const Text(
                    'Kefalet İle Tahliye',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Body
                  Text(
                    'Zindan cezanı $bailCost 💎 harcayarak sonlandırmak ve derhal serbest kalmak istiyor musun?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.mutedTitanium,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Financial Balance Card
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF07090F),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusSm),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text(
                              'Ödenecek Kefalet:',
                              style: TextStyle(
                                color: AppColors.mutedTitanium,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '$bailCost 💎',
                              style: const TextStyle(
                                color: AppColors.coralFlare,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            const Text(
                              'Kalan Kasa:',
                              style: TextStyle(
                                color: AppColors.mutedTitanium,
                                fontSize: 11,
                              ),
                            ),
                            Text(
                              '${(remainingBalance % 1 == 0) ? remainingBalance.toInt() : remainingBalance} 💎',
                              style: const TextStyle(
                                color: AppColors.liquidGold,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // Action Buttons
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Hücrede Kal',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.coralFlare,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                              side: BorderSide(
                                color: AppColors.liquidGold
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 4,
                          ),
                          child: const Text(
                            'Kefaleti Öde',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
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
        );
      },
    );
  }

  /// Dark Gothic Insufficient Gems Dialog with Lawyer Comparison and Shop navigation.
  static Future<void> showInsufficientGems(
    BuildContext context, {
    required int bailCost,
    required num playerGems,
    VoidCallback? onGoToShop,
    VoidCallback? onOpenLawyerComparison,
  }) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: const Color(0xF20F1320),
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: Border.all(
                  color: AppColors.mysticRuby.withValues(alpha: 0.45),
                  width: 1.4,
                ),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.mysticRuby.withValues(alpha: 0.15),
                      border: Border.all(
                        color: AppColors.mysticRuby.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.mysticRuby.withValues(alpha: 0.3),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        Opacity(
                          opacity: 0.6,
                          child: Image.asset(
                            'assets/images/aion2_ui/hud_action_bar_slot.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                        const Center(
                          child: Text('💎', style: TextStyle(fontSize: 22)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Text(
                    'Yetersiz Elmas',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Kefalet bedeli $bailCost 💎 gerektiriyor.\nMevcut kasanızda yalnızca $playerGems 💎 var.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.mutedTitanium,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.15),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Kapat',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            if (onGoToShop != null) {
                              onGoToShop();
                            } else {
                              context.go('/shop');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusSm),
                              side: BorderSide(
                                color: AppColors.goldLight
                                    .withValues(alpha: 0.4),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Dükkana Git',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
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
        );
      },
    );
  }

  /// Dark Gothic Full Modal Dialog for Lawyer Fee and Defense Comparison.
  static Future<void> showLawyerFeeComparison(
    BuildContext context, {
    required int bailCost,
    required num playerGems,
    required int remainingMinutes,
    num? playerGold,
    int? guardBribeCost,
    bool guildLawyerAvailable = true,
    VoidCallback? onPayFullBail,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext ctx) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  PrisonLawyerFeeComparisonPanel(
                    bailCost: bailCost,
                    playerGems: playerGems,
                    remainingMinutes: remainingMinutes,
                    playerGold: playerGold,
                    guardBribeCost: guardBribeCost,
                    guildLawyerAvailable: guildLawyerAvailable,
                    onPayFullBail: onPayFullBail,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('Kapat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Gothic Amnesty Card when Player is Free.
class PrisonFreeStatusCard extends StatelessWidget {
  const PrisonFreeStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xF20B191C),
                Color(0xF2081215),
                Color(0xF5050C0E),
              ],
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: AppColors.accentTeal.withValues(alpha: 0.45),
              width: 1.3,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.65),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.accentTeal.withValues(alpha: 0.16),
                blurRadius: 24,
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              // Decorative Corner Rivets & Brackets
              const Positioned(top: 6, left: 6, child: _GothicIronRivet()),
              const Positioned(top: 6, right: 6, child: _GothicIronRivet()),
              const Positioned(bottom: 6, left: 6, child: _GothicIronRivet()),
              const Positioned(bottom: 6, right: 6, child: _GothicIronRivet()),
              const Positioned(
                top: 4,
                left: 4,
                child: _GothicCornerBracket(isTop: true, isLeft: true),
              ),
              const Positioned(
                top: 4,
                right: 4,
                child: _GothicCornerBracket(isTop: true, isLeft: false),
              ),

              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentTeal.withValues(alpha: 0.15),
                        border: Border.all(
                          color: AppColors.accentTeal.withValues(alpha: 0.55),
                          width: 1.5,
                        ),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: AppColors.accentTeal.withValues(alpha: 0.25),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Opacity(
                            opacity: 0.6,
                            child: Image.asset(
                              'assets/images/aion2_ui/hud_action_bar_slot.png',
                              width: 54,
                              height: 54,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                          const Text('🕊️', style: TextStyle(fontSize: 28)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'ZİNDAN KAPILARI AÇIK',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Özgürsün',
                      style: TextStyle(
                        color: AppColors.accentTeal,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Şu an cezaevinde hükümlü değilsin. Krallık yasalarına uyduğun sürece zindana düşmezsin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.mutedTitanium,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtle Ornamental Gothic Iron Rivet with Metallic 3D Emboss
class _GothicIronRivet extends StatelessWidget {
  const _GothicIronRivet();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 0.8,
          colors: <Color>[
            Color(0xFF718096),
            Color(0xFF2D3748),
            Color(0xFF1A202C),
          ],
        ),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Colors.black,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF4A5568),
          width: 0.5,
        ),
      ),
    );
  }
}

/// Ornamental Gothic Iron Corner Bracket for AAA Glass Cards
class _GothicCornerBracket extends StatelessWidget {
  const _GothicCornerBracket({
    this.isTop = true,
    this.isLeft = true,
    this.size = 14.0,
  });

  final bool isTop;
  final bool isLeft;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GothicBracketPainter(
        isTop: isTop,
        isLeft: isLeft,
      ),
    );
  }
}

class _GothicBracketPainter extends CustomPainter {
  const _GothicBracketPainter({
    required this.isTop,
    required this.isLeft,
  });

  final bool isTop;
  final bool isLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint ironPaint = Paint()
      ..color = const Color(0xFF4A5568)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    final Paint goldHighlight = Paint()
      ..color = AppColors.liquidGold.withValues(alpha: 0.55)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final Path path = Path();
    final double w = size.width;
    final double h = size.height;

    if (isTop && isLeft) {
      path.moveTo(0, h);
      path.lineTo(0, 0);
      path.lineTo(w, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(w, h);
      path.lineTo(w, 0);
      path.lineTo(0, 0);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, h);
      path.lineTo(w, h);
    } else {
      path.moveTo(w, 0);
      path.lineTo(w, h);
      path.lineTo(0, h);
    }

    canvas.drawPath(path, ironPaint);
    canvas.drawPath(path, goldHighlight);
  }

  @override
  bool shouldRepaint(covariant _GothicBracketPainter oldDelegate) =>
      oldDelegate.isTop != isTop || oldDelegate.isLeft != isLeft;
}

/// Dynamic Glowing Iron Chains Header Painter
class _GothicChainsPainter extends CustomPainter {
  const _GothicChainsPainter({this.glowProgress = 0.0});

  final double glowProgress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Paint chainPaint = Paint()
      ..color = const Color(0xFF333E52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final Paint chainGlow = Paint()
      ..color = AppColors.coralFlare.withValues(
        alpha: 0.15 + glowProgress * 0.18,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    final double midY = size.height * 0.5;
    final int linkCount = (size.width / 16).floor().clamp(2, 24);
    final double step = size.width / linkCount;

    for (int i = 0; i < linkCount; i++) {
      final double cx = i * step + step * 0.5;
      final Rect ovalRect = Rect.fromCenter(
        center: Offset(cx, midY),
        width: step * 0.8,
        height: size.height * 0.7,
      );
      canvas.drawOval(ovalRect, chainGlow);
      canvas.drawOval(ovalRect, chainPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GothicChainsPainter oldDelegate) =>
      oldDelegate.glowProgress != glowProgress;
}

/// Safe Asset Image with Graceful Null/Error Fallback
class _SafeAion2Image extends StatelessWidget {
  const _SafeAion2Image({
    required this.assetPath,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.opacity = 1.0,
    this.fallback,
  });

  final String assetPath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double opacity;
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (BuildContext ctx, Object error, StackTrace? stack) =>
            fallback ?? SizedBox(width: width, height: height),
      ),
    );
  }
}

