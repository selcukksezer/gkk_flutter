import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/kingdom_market_blessing_model.dart';
import '../../providers/kingdom_market_blessing_provider.dart';
import '../../theme/app_colors.dart';
import 'kingdom_crest_icons.dart';
import 'kingdom_glass_card.dart';

/// 2027 Aion-2 Obsidian-Glass & Celestial Blessing Design Tokens
abstract final class _AionBlessingTokens {
  static const Color divineGold = Color(0xFFE5C158);
  static const Color divineGoldLight = Color(0xFFFBE89D);
  static const Color divineGoldDark = Color(0xFFB59332);
  static const Color etherCyan = Color(0xFF00E5FF);
  static const Color celestialAzure = Color(0xFF0E1A2E);
  static const Color obsidianVoid = Color(0xFF090D15);
  static const Color obsidianGoldTint = Color(0xF2151208);
}

/// Modernized 2027 Aion-2 mobile kingdom market blessing banner.
///
/// Features:
/// - Obsidian frosted glass banner with divine gold (#E5C158) blessing gradient
///   and ether cyan (#00E5FF) sparkle accents
/// - BackdropFilter blur (sigma 16) with multi-layered subtle ambient glow shadow
/// - Interactive claim button with tactile HapticFeedback (mediumImpact) & luminous gold styling
/// - Responsive mobile layout with adaptive badges & safe area protection
/// - 100% preserves existing provider state & constructor parameters
class KingdomMarketBlessingBanner extends ConsumerWidget {
  const KingdomMarketBlessingBanner({
    super.key,
    this.locationLabel,
    this.margin = const EdgeInsets.only(bottom: 10),
    this.onClaim,
    this.onTap,
    this.showClaimButton = true,
    this.claimLabel,
    this.useSafeArea = false,
  });

  final String? locationLabel;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onClaim;
  final VoidCallback? onTap;
  final bool showClaimButton;
  final String? claimLabel;
  final bool useSafeArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final KingdomMarketBlessingStatus blessing = ref.watch(kingdomMarketBlessingProvider);
    if (!blessing.active) return const SizedBox.shrink();

    final String remaining = blessing.remainingLabel();

    Widget banner = Padding(
      padding: margin,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: _AionBlessingTokens.divineGold.withValues(alpha: 0.16),
              blurRadius: 22,
              spreadRadius: -2,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: _AionBlessingTokens.etherCyan.withValues(alpha: 0.10),
              blurRadius: 16,
              spreadRadius: -4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: KingdomGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          borderRadius: 16,
          blurSigma: 16,
          accentGlowColor: _AionBlessingTokens.divineGold,
          elevation: 0,
          onTap: onTap,
          borderGradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              _AionBlessingTokens.divineGold.withValues(alpha: 0.90),
              _AionBlessingTokens.etherCyan.withValues(alpha: 0.70),
              const Color(0xFF38BDF8).withValues(alpha: 0.35),
              _AionBlessingTokens.divineGold.withValues(alpha: 0.80),
              Colors.white.withValues(alpha: 0.30),
            ],
            stops: const <double>[0.0, 0.28, 0.65, 0.88, 1.0],
          ),
          backgroundGradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              _AionBlessingTokens.obsidianGoldTint, // Dark obsidian with subtle warm gold luster
              _AionBlessingTokens.celestialAzure,  // Translucent celestial azure
              _AionBlessingTokens.obsidianVoid,    // Deep obsidian void base
            ],
            stops: <double>[0.0, 0.50, 1.0],
          ),
          child: Stack(
            children: <Widget>[
              // Celestial Ether Cyan & Divine Gold Sparkle Accents
              const Positioned.fill(
                child: CustomPaint(
                  painter: _EtherSparklePainter(),
                ),
              ),
              // Content Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  // Animated Celestial Crown Crest Icon
                  const KingdomCrestIcon(
                    type: KingdomCrestType.blessing,
                    size: 42,
                    showGlow: true,
                    animatedPulse: true,
                  ),
                  const SizedBox(width: 12),
                  // Content Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        // Header Row with Title, Timer Pill and Interactive Claim Button
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                runSpacing: 4,
                                children: <Widget>[
                                  Text(
                                    'KRAL İNDİRİMİ',
                                    style: TextStyle(
                                      color: _AionBlessingTokens.divineGold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                      shadows: <Shadow>[
                                        Shadow(
                                          color: _AionBlessingTokens.divineGold.withValues(alpha: 0.50),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (remaining.isNotEmpty)
                                    _BlessingTimerBadge(remaining: remaining),
                                ],
                              ),
                            ),
                            if (showClaimButton) ...<Widget>[
                              const SizedBox(width: 8),
                              _BlessingClaimButton(
                                label: claimLabel,
                                onPressed: () => _handleClaim(context, blessing),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Message description
                        Text(
                          blessing.bannerMessage(locationLabel: locationLabel),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Currency Discount Badges
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            if (blessing.goldDiscountPct > 0)
                              _DiscountChip(
                                icon: Icons.monetization_on_rounded,
                                label: 'Altın -%${blessing.goldDiscountPct}',
                                color: _AionBlessingTokens.divineGold,
                              ),
                            if (blessing.gemDiscountPct > 0)
                              _DiscountChip(
                                icon: Icons.diamond_rounded,
                                label: 'Elmas -%${blessing.gemDiscountPct}',
                                color: _AionBlessingTokens.etherCyan,
                              ),
                            if (blessing.activatorLabel.isNotEmpty)
                              _ActivatorChip(label: blessing.activatorLabel),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (useSafeArea) {
      banner = SafeArea(
        top: false,
        bottom: false,
        child: banner,
      );
    } else {
      banner = SafeArea(
        top: false,
        bottom: false,
        minimum: EdgeInsets.zero,
        child: banner,
      );
    }

    return banner;
  }

  void _handleClaim(BuildContext context, KingdomMarketBlessingStatus blessing) {
    if (onClaim != null) {
      onClaim!();
      return;
    }
    _showBlessingDetailsSheet(context, blessing);
  }

  void _showBlessingDetailsSheet(BuildContext context, KingdomMarketBlessingStatus blessing) {
    if (!context.mounted) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: KingdomGlassCard(
              borderRadius: 22,
              blurSigma: 16,
              accentGlowColor: _AionBlessingTokens.divineGold,
              borderGradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  _AionBlessingTokens.divineGold,
                  _AionBlessingTokens.etherCyan.withValues(alpha: 0.70),
                  _AionBlessingTokens.divineGold.withValues(alpha: 0.80),
                ],
              ),
              backgroundGradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  _AionBlessingTokens.obsidianGoldTint,
                  _AionBlessingTokens.celestialAzure,
                  _AionBlessingTokens.obsidianVoid,
                ],
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const KingdomCrestIcon(
                        type: KingdomCrestType.blessing,
                        size: 38,
                        showGlow: true,
                        animatedPulse: true,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'KRALİYET KUTSAMASI',
                              style: TextStyle(
                                color: _AionBlessingTokens.divineGold,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              blessing.activatorLabel,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (blessing.remainingLabel().isNotEmpty)
                        _BlessingTimerBadge(remaining: blessing.remainingLabel()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _AionBlessingTokens.divineGold.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          color: _AionBlessingTokens.etherCyan,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pazar ve mağaza alışverişlerinde %${blessing.goldDiscountPct} altın ve %${blessing.gemDiscountPct} elmas indirimi sepetinize otomatik uygulanır.',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(sheetContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _AionBlessingTokens.divineGold,
                        foregroundColor: const Color(0xFF0A0F1D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'ANLADIM',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
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

/// Interactive claim button with tactile HapticFeedback & luminous gold styling
class _BlessingClaimButton extends StatelessWidget {
  const _BlessingClaimButton({
    required this.onPressed,
    this.label,
  });

  final VoidCallback onPressed;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final String effectiveLabel = label ?? 'FAYDALAN';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onPressed();
        },
        borderRadius: BorderRadius.circular(10),
        splashColor: _AionBlessingTokens.etherCyan.withValues(alpha: 0.35),
        highlightColor: _AionBlessingTokens.divineGold.withValues(alpha: 0.25),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                _AionBlessingTokens.divineGoldLight,
                _AionBlessingTokens.divineGold,
                _AionBlessingTokens.divineGoldDark,
              ],
              stops: <double>[0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _AionBlessingTokens.etherCyan.withValues(alpha: 0.65),
              width: 0.9,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: _AionBlessingTokens.divineGold.withValues(alpha: 0.45),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              BoxShadow(
                color: _AionBlessingTokens.etherCyan.withValues(alpha: 0.20),
                blurRadius: 6,
                spreadRadius: -1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.auto_awesome,
                size: 11,
                color: Color(0xFF0A0F1D),
              ),
              const SizedBox(width: 4),
              Text(
                effectiveLabel,
                style: const TextStyle(
                  color: Color(0xFF0A0F1D),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Floating glowing timer pill for remaining blessing duration
class _BlessingTimerBadge extends StatelessWidget {
  const _BlessingTimerBadge({required this.remaining});

  final String remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
      decoration: BoxDecoration(
        color: const Color(0xFF131C2E).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _AionBlessingTokens.divineGold.withValues(alpha: 0.65),
          width: 0.8,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _AionBlessingTokens.divineGold.withValues(alpha: 0.25),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.timer_outlined,
            size: 11,
            color: _AionBlessingTokens.divineGold,
          ),
          const SizedBox(width: 4),
          Text(
            remaining,
            style: const TextStyle(
              color: _AionBlessingTokens.divineGold,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Styled discount pill with colored glow
class _DiscountChip extends StatelessWidget {
  const _DiscountChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.50),
          width: 0.8,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill showing who activated the royal blessing
class _ActivatorChip extends StatelessWidget {
  const _ActivatorChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.14),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.shield_outlined,
            size: 10,
            color: Colors.white.withValues(alpha: 0.70),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.80),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter to render ethereal cyan and divine gold celestial sparkles
class _EtherSparklePainter extends CustomPainter {
  const _EtherSparklePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Top-right ethereal cyan sparkle
    _drawSparkle(
      canvas,
      Offset(size.width - 24, 14),
      4.5,
      _AionBlessingTokens.etherCyan.withValues(alpha: 0.75),
    );

    // Divine gold sparkle near top-center
    _drawSparkle(
      canvas,
      Offset(size.width * 0.52, 10),
      3.2,
      _AionBlessingTokens.divineGold.withValues(alpha: 0.60),
    );

    // Ether cyan micro sparkle near bottom right
    _drawSparkle(
      canvas,
      Offset(size.width - 12, size.height - 14),
      2.8,
      _AionBlessingTokens.etherCyan.withValues(alpha: 0.50),
    );

    // Micro gold sparkle near crest
    _drawSparkle(
      canvas,
      const Offset(46, 12),
      2.5,
      _AionBlessingTokens.divineGold.withValues(alpha: 0.55),
    );

    // Soft ether cyan ambient light glow spot at top right corner
    final Paint cyanGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          _AionBlessingTokens.etherCyan.withValues(alpha: 0.12),
          _AionBlessingTokens.etherCyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width - 20, 16), radius: 36));
    canvas.drawCircle(Offset(size.width - 20, 16), 36, cyanGlowPaint);

    // Soft divine gold ambient light glow spot behind crest
    final Paint goldGlowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          _AionBlessingTokens.divineGold.withValues(alpha: 0.14),
          _AionBlessingTokens.divineGold.withValues(alpha: 0.0),
        ],
      ).createShader(const Rect.fromLTWH(0, 0, 70, 70));
    canvas.drawCircle(const Offset(28, 28), 35, goldGlowPaint);
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
    final Paint glowPaint = Paint()
      ..color = color.withValues(alpha: color.a * 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(center, size * 0.8, glowPaint);

    final Path path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + size)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - size, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - size)
      ..close();

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    final Paint corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size * 0.25, corePaint);
  }

  @override
  bool shouldRepaint(covariant _EtherSparklePainter oldDelegate) => false;
}
