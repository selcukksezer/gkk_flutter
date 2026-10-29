import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/comeback_summary_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'comeback_buff_badge.dart';
import 'comeback_gift_card.dart';
import 'comeback_milestone_track.dart';
import 'comeback_models.dart';
import 'comeback_particle_burst.dart';

// 2027 Aion 2 Obsidian-Glass & Luminescence Design Tokens
const Color _kCelestialGold = Color(0xFFE5C158);
const Color _kCelestialGoldLight = Color(0xFFFFF2B2);
const Color _kEtherCyan = Color(0xFF00E5FF);
const Color _kObsidianGlassVoid = Color(0xFF06090F);
const Color _kObsidianGlassDark = Color(0xF00A0E18);
const Color _kObsidianGlassMedium = Color(0xF2101726);

/// 2027 Aion 2 Mobile Standard Returning Warrior Comeback Rewards Portal.
///
/// Responsive to 390x844 mobile viewport with SafeArea padding,
/// particle burst celebrations, tiered milestone progression, and buff indicators.
class ComebackRewardsPortal extends StatefulWidget {
  const ComebackRewardsPortal({
    super.key,
    required this.summary,
    this.buffInfo,
    this.giftCardData,
    this.milestoneTiers,
    this.currentDay = 1,
    this.onClose,
    this.onActionItemTap,
    this.onClaimGift,
    this.onClaimMilestone,
  });

  final ComebackSummary summary;
  final ComebackBuffInfo? buffInfo;
  final ComebackGiftCardData? giftCardData;
  final List<ComebackMilestoneTier>? milestoneTiers;
  final int currentDay;
  final VoidCallback? onClose;
  final void Function(ComebackSummaryItem item)? onActionItemTap;
  final VoidCallback? onClaimGift;
  final void Function(ComebackMilestoneTier tier)? onClaimMilestone;

  @override
  State<ComebackRewardsPortal> createState() => _ComebackRewardsPortalState();
}

class _ComebackRewardsPortalState extends State<ComebackRewardsPortal>
    with SingleTickerProviderStateMixin {
  late ComebackBuffInfo _buffInfo;
  late ComebackGiftCardData _giftCardData;
  late List<ComebackMilestoneTier> _milestoneTiers;
  final ComebackParticleBurstController _globalBurstCtrl =
      ComebackParticleBurstController();
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    // Initial activation haptic feedback
    HapticFeedback.mediumImpact();

    _buffInfo = widget.buffInfo ??
        ComebackBuffInfo.defaultBuff(
          durationDays: (widget.summary.offlineHours / 24).clamp(3, 14).round(),
        );

    _giftCardData = widget.giftCardData ??
        ComebackGiftCardData.defaultForOffline(
          offlineHours: widget.summary.offlineHours,
        );

    _milestoneTiers = widget.milestoneTiers ??
        ComebackMilestoneTier.generateDefaultTrack(
          currentProgressDay: widget.currentDay,
        );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _handleGiftClaimed() {
    HapticFeedback.mediumImpact();
    setState(() {
      _giftCardData = _giftCardData.copyWith(
        isClaimed: true,
        claimedAt: DateTime.now(),
      );
    });
    _globalBurstCtrl.burst(count: 65);
    widget.onClaimGift?.call();
  }

  void _handleMilestoneClaimed(ComebackMilestoneTier tier) {
    HapticFeedback.mediumImpact();
    setState(() {
      final int idx = _milestoneTiers.indexWhere((ComebackMilestoneTier t) => t.day == tier.day);
      if (idx != -1) {
        _milestoneTiers[idx] = tier.copyWith(isClaimed: true, isReady: false);
      }
    });
    _globalBurstCtrl.burst(count: 45);
    widget.onClaimMilestone?.call(tier);
  }

  String _formatOfflineGreeting(double hours) {
    if (hours >= 24) {
      final int days = (hours / 24).floor();
      return '$days gündür Atreia\'dan uzaktaydın. Kadim kutsamalar ve geri dönüş ganimetleri seni bekliyor!';
    }
    if (hours >= 1) {
      final int h = hours.floor();
      return '$h saattir uzaktaydın. Savaş meydanına hoş geldin, Savaşçı!';
    }
    return 'Kısa bir aradan sonra tekrar hoş geldin, Savaşçı!';
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final EdgeInsets safeInsets = MediaQuery.paddingOf(context);
    final double maxDialogHeight = screenSize.height * 0.90;

    return ComebackParticleBurst(
      controller: _globalBurstCtrl,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: maxDialogHeight,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[
                          _kObsidianGlassDark,
                          _kObsidianGlassVoid,
                          _kObsidianGlassMedium,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                      border: Border.all(
                        color: _kCelestialGold.withValues(alpha: 0.5),
                        width: 1.4,
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: _kCelestialGold.withValues(alpha: 0.22),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: _kEtherCyan.withValues(alpha: 0.16),
                          blurRadius: 36,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: <Widget>[
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _PortalEnergyStreamsPainter(
                                animation: _pulseCtrl,
                              ),
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _buildTopBar(context, safeInsets),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  safeInsets.bottom > 0 ? safeInsets.bottom : 16,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: <Widget>[
                                    const SizedBox(height: 6),
                                    _buildWelcomeGreeting(),
                                    const SizedBox(height: 14),
                                    ComebackBuffBadge(buffInfo: _buffInfo),
                                    const SizedBox(height: 14),
                                    ComebackGiftCard(
                                      data: _giftCardData,
                                      onClaim: _handleGiftClaimed,
                                    ),
                                    const SizedBox(height: 14),
                                    ComebackMilestoneTrack(
                                      tiers: _milestoneTiers,
                                      currentDay: widget.currentDay,
                                      onClaimTier: _handleMilestoneClaimed,
                                    ),
                                    if (widget.summary.items.isNotEmpty) ...<Widget>[
                                      const SizedBox(height: 16),
                                      _buildPendingActionsSection(),
                                    ],
                                    const SizedBox(height: 20),
                                    _buildFooterCta(context),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildTopBar(BuildContext context, EdgeInsets safeInsets) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18,
        safeInsets.top > 0 ? 12 : 14,
        14,
        10,
      ),
      child: Row(
        children: <Widget>[
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (BuildContext context, Widget? child) {
              final double pulse = _pulseCtrl.value;
              return Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      _kCelestialGold,
                      _kCelestialGoldLight,
                    ],
                  ),
                  border: Border.all(
                    color: _kEtherCyan.withValues(alpha: 0.6 + 0.3 * pulse),
                    width: 1.6,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _kCelestialGold.withValues(alpha: 0.4 + 0.2 * pulse),
                      blurRadius: 14 + 6 * pulse,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: _kEtherCyan.withValues(alpha: 0.25 * pulse),
                      blurRadius: 18,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.wb_twilight_rounded,
                  color: Color(0xFF06090F),
                  size: 24,
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        'Geri Dönen Savaşçı',
                        style: GoogleFonts.urbanist(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          shadows: const <Shadow>[
                            Shadow(
                              color: Color(0x66E5C158),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kEtherCyan.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _kEtherCyan.withValues(alpha: 0.45),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '2027 AION 2',
                        style: GoogleFonts.urbanist(
                          color: _kEtherCyan,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Aion 2 Özel Karşılama Portalı',
                  style: GoogleFonts.urbanist(
                    color: _kCelestialGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              if (widget.onClose != null) {
                widget.onClose!();
              } else {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.close_rounded, color: AppColors.mutedTitanium),
            tooltip: 'Kapat',
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeGreeting() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: _kEtherCyan.withValues(alpha: 0.32),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kEtherCyan.withValues(alpha: 0.08),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _kEtherCyan.withValues(alpha: 0.14),
              border: Border.all(
                color: _kEtherCyan.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: const Icon(
              Icons.shield_moon_rounded,
              color: _kEtherCyan,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _formatOfflineGreeting(widget.summary.offlineHours),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingActionsSection() {
    final List<ComebackSummaryItem> items = widget.summary.items;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 3,
                  height: 12,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: _kCelestialGold,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                Text(
                  'YOKLUĞUNDA GERÇEKLEŞENLER',
                  style: GoogleFonts.urbanist(
                    color: _kCelestialGold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _kEtherCyan.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _kEtherCyan.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: Text(
                '${items.length} Bekleyen Bildirim',
                style: GoogleFonts.urbanist(
                  color: _kEtherCyan,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (BuildContext context, int index) {
            final ComebackSummaryItem item = items[index];
            return _PendingActionTile(
              item: item,
              onTap: () {
                HapticFeedback.mediumImpact();
                widget.onActionItemTap?.call(item);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFooterCta(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _kCelestialGold.withValues(alpha: 0.4),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: _kEtherCyan.withValues(alpha: 0.25),
            blurRadius: 22,
            spreadRadius: -2,
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          if (widget.onClose != null) {
            widget.onClose!();
          } else {
            Navigator.of(context).pop();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _kCelestialGold,
          foregroundColor: const Color(0xFF06090F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _kEtherCyan.withValues(alpha: 0.7),
              width: 1.2,
            ),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.play_arrow_rounded, size: 22, color: Color(0xFF06090F)),
            const SizedBox(width: 8),
            Text(
              'Atreia\'ya Dönüş Yap',
              style: GoogleFonts.urbanist(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.4,
                color: const Color(0xFF06090F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingActionTile extends StatelessWidget {
  const _PendingActionTile({
    required this.item,
    required this.onTap,
  });

  final ComebackSummaryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color accent = item.kind.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 0.9,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.45),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(item.kind.icon, color: accent, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        style: GoogleFonts.urbanist(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.mutedTitanium,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.55),
                      width: 0.9,
                    ),
                  ),
                  child: Text(
                    item.ctaLabel,
                    style: GoogleFonts.urbanist(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
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

/// Custom painter rendering 2027 Aion 2 celestial gold and ether cyan energy stream conduits.
class _PortalEnergyStreamsPainter extends CustomPainter {
  _PortalEnergyStreamsPainter({required this.animation}) : super(repaint: animation);

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = animation.value;

    // Ether cyan ambient energy bloom (top right)
    final Paint cyanGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          _kEtherCyan.withValues(alpha: 0.12 + 0.06 * t),
          _kEtherCyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.85, 45),
        radius: 140,
      ));
    canvas.drawCircle(Offset(size.width * 0.85, 45), 140, cyanGlow);

    // Celestial gold ambient radiance (top left)
    final Paint goldGlow = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          _kCelestialGold.withValues(alpha: 0.14 + 0.06 * (1.0 - t)),
          _kCelestialGold.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
        center: const Offset(35, 25),
        radius: 130,
      ));
    canvas.drawCircle(const Offset(35, 25), 130, goldGlow);

    // Ethereal cyan & celestial gold energy stream ribbons
    final Paint streamPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = LinearGradient(
        colors: <Color>[
          _kCelestialGold.withValues(alpha: 0.0),
          _kEtherCyan.withValues(alpha: 0.22 + 0.18 * t),
          _kCelestialGold.withValues(alpha: 0.35 + 0.10 * (1.0 - t)),
          _kEtherCyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 100));

    final Path streamPath = Path()
      ..moveTo(0, 68)
      ..cubicTo(
        size.width * 0.32,
        58 + 12 * t,
        size.width * 0.68,
        78 - 12 * t,
        size.width,
        62,
      );
    canvas.drawPath(streamPath, streamPaint);
  }

  @override
  bool shouldRepaint(_PortalEnergyStreamsPainter oldDelegate) => true;
}
