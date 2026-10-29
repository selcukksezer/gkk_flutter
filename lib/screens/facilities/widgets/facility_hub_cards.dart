import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:motor/motor.dart';

import '../../../theme/app_colors.dart';
import 'facilities_ui.dart';

/// Returns real high-fantasy Aion background artwork asset by facility tier.
String _tierBackgroundAsset(int tier) {
  switch (tier) {
    case 1:
      return 'assets/images/backgrounds/asmodae/bg_morheim_volcano.png';
    case 2:
      return 'assets/images/backgrounds/elysea/bg_poeta_clovers.png';
    case 3:
      return 'assets/images/backgrounds/dungeons/bg_beshmundir_crypt.png';
    default:
      return 'assets/images/backgrounds/dungeons/bg_abyss_core_warzone.png';
  }
}

/// Returns Roman numeral representation for tier labeling.
String _tierRoman(int tier) {
  switch (tier) {
    case 1:
      return 'TIER I';
    case 2:
      return 'TIER II';
    case 3:
      return 'TIER III';
    case 4:
      return 'TIER IV';
    case 5:
      return 'TIER V';
    default:
      return 'TIER $tier';
  }
}

/// Tier Bölümü — Aion-2 Frosted Glass & Luminous Accent with Atmospheric Backdrop.
class FacTierSection extends StatelessWidget {
  const FacTierSection({
    super.key,
    required this.tier,
    required this.title,
    required this.trailing,
    required this.accentColor,
    required this.children,
  });

  final int tier;
  final String title;
  final String trailing;
  final Color accentColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (tier > 1) ...<Widget>[
            _FacTierDivider(accentColor: accentColor),
            const SizedBox(height: 14),
          ],
          FacGlassPanel(
            borderColor: accentColor.withValues(alpha: 0.42),
            glowColor: accentColor.withValues(alpha: 0.16),
            padding: const EdgeInsets.all(12),
            borderRadius: FacilitiesUi.radiusLg,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(FacilitiesUi.radiusLg),
                    child: Opacity(
                      opacity: 0.08,
                      child: Image.asset(
                        _tierBackgroundAsset(tier),
                        fit: BoxFit.cover,
                        errorBuilder: (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) =>
                            const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 4,
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                accentColor,
                                accentColor.withValues(alpha: 0.35),
                              ],
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.55),
                                blurRadius: 10,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: accentColor.withValues(alpha: 0.14),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.40),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            _tierRoman(tier),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: accentColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                        if (trailing.isNotEmpty) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2.5,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: accentColor.withValues(alpha: 0.14),
                              border: Border.all(
                                color: accentColor.withValues(alpha: 0.45),
                                width: 0.9,
                              ),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.20),
                                  blurRadius: 6,
                                  spreadRadius: -1,
                                ),
                              ],
                            ),
                            child: Text(
                              trailing,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: accentColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...children,
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FacTierDivider extends StatelessWidget {
  const _FacTierDivider({required this.accentColor});

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.transparent,
                    accentColor.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accentColor,
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.70),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    accentColor.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2 Sütunlu Kart Satırı — Grid aspect-ratio taşmasını önler.
class FacFacilityCardRow extends StatelessWidget {
  const FacFacilityCardRow({
    super.key,
    required this.left,
    this.right,
    this.bottomPadding = 10.0,
  });

  final Widget left;
  final Widget? right;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: left),
          const SizedBox(width: 10),
          Expanded(child: right ?? const SizedBox.shrink()),
        ],
      ),
    );
  }
}

/// Metadata extracted from facility footer strings to drive AAA HUD gauges.
class _FacilityCardMetadata {
  const _FacilityCardMetadata({
    this.rate,
    this.level,
    this.readyCount,
    required this.isProducing,
    required this.isReady,
    required this.isIdle,
  });

  final int? rate;
  final int? level;
  final int? readyCount;
  final bool isProducing;
  final bool isReady;
  final bool isIdle;

  factory _FacilityCardMetadata.fromFooter(String footer) {
    int? parsedRate;
    final RegExp rateMatch = RegExp(r'\+([0-9]+)/dk');
    final Match? match = rateMatch.firstMatch(footer);
    if (match != null) {
      parsedRate = int.tryParse(match.group(1) ?? '');
    }

    int? parsedLevel;
    final RegExp levelMatch = RegExp(r'Lv\.\s*([0-9]+)');
    final Match? lMatch = levelMatch.firstMatch(footer);
    if (lMatch != null) {
      parsedLevel = int.tryParse(lMatch.group(1) ?? '');
    }

    int? parsedReadyCount;
    final RegExp readyMatch = RegExp(r'🎁\s*([0-9]+)\s*Hazır');
    final Match? rMatch = readyMatch.firstMatch(footer);
    if (rMatch != null) {
      parsedReadyCount = int.tryParse(rMatch.group(1) ?? '');
    }

    final bool isReady = footer.contains('🎁') || footer.contains('Hazır');
    final bool isProducing =
        footer.contains('⚡') || footer.contains('Üretimde');
    final bool isIdle = footer.contains('💤') || footer.contains('Boşta');

    return _FacilityCardMetadata(
      rate: parsedRate,
      level: parsedLevel,
      readyCount: parsedReadyCount,
      isProducing: isProducing,
      isReady: isReady,
      isIdle: isIdle,
    );
  }
}

/// Real Aion environment background artwork mapped to facility archetype.
String _facilityBackgroundFor({
  required String name,
  required String icon,
}) {
  final String lower = '${name.toLowerCase()} $icon';
  if (lower.contains('maden') ||
      lower.contains('ocak') ||
      lower.contains('demir') ||
      lower.contains('taş') ||
      lower.contains('elementel') ||
      icon == '⛏️' ||
      icon == '🪨' ||
      icon == '🔥') {
    return 'assets/images/backgrounds/asmodae/bg_morheim_volcano.png';
  }
  if (lower.contains('çiftlik') ||
      lower.contains('kereste') ||
      lower.contains('bahçe') ||
      lower.contains('hayvan') ||
      lower.contains('arı') ||
      lower.contains('mantar') ||
      icon == '🌾' ||
      icon == '🪵' ||
      icon == '🌿' ||
      icon == '🐄' ||
      icon == '🐝' ||
      icon == '🍄') {
    return 'assets/images/backgrounds/elysea/bg_poeta_clovers.png';
  }
  if (lower.contains('rune') ||
      lower.contains('gölge') ||
      lower.contains('simya') ||
      lower.contains('zaman') ||
      lower.contains('kutsal') ||
      lower.contains('mithril') ||
      icon == '🔮' ||
      icon == '🕸️' ||
      icon == '⌛' ||
      icon == '⛲' ||
      icon == '🧪' ||
      icon == '⚔️') {
    return 'assets/images/backgrounds/dungeons/bg_beshmundir_crypt.png';
  }
  return 'assets/images/backgrounds/asmodae/bg_pandaemonium_capital.png';
}

/// Real chest asset selection based on accent color.
String _facilityChestAssetFor(Color accentColor) {
  if (accentColor == AppColors.toxicNeon) {
    return 'assets/chest/kasalav.png';
  }
  if (accentColor == AppColors.cyberFuchsia ||
      accentColor == AppColors.accentPurple) {
    return 'assets/chest/kasawitch.png';
  }
  return 'assets/chest/kasacevher.png';
}

/// Custom radial arc painter for production rate meter.
class _FacProductionRateArcPainter extends CustomPainter {
  const _FacProductionRateArcPainter({
    required this.progress,
    required this.accentColor,
    required this.trackColor,
  });

  final double progress;
  final Color accentColor;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) / 2) - 1.8;
    if (radius <= 0) return;

    const double startAngle = 0.75 * math.pi;
    const double totalSweep = 1.5 * math.pi;

    // Track
    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      trackPaint,
    );

    // Active arc with glow
    final double sweep = totalSweep * progress.clamp(0.08, 1.0);
    final Paint arcPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final Paint glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      glowPaint,
    );

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      arcPaint,
    );

    // Tip pip
    final double tipAngle = startAngle + sweep;
    final Offset tipPos = Offset(
      center.dx + radius * math.cos(tipAngle),
      center.dy + radius * math.sin(tipAngle),
    );
    final Paint pipPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(tipPos, 1.3, pipPaint);
  }

  @override
  bool shouldRepaint(covariant _FacProductionRateArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.trackColor != trackColor;
  }
}

/// Sleek micro production rate gauge.
class _FacProductionRateGauge extends StatelessWidget {
  const _FacProductionRateGauge({
    required this.rate,
    required this.accentColor,
    this.isProducing = false,
  });

  final int? rate;
  final Color accentColor;
  final bool isProducing;

  @override
  Widget build(BuildContext context) {
    final double progress = rate != null
        ? (rate! / 100.0).clamp(0.15, 1.0)
        : (isProducing ? 0.80 : 0.35);

    return SizedBox(
      width: 13,
      height: 13,
      child: CustomPaint(
        painter: _FacProductionRateArcPainter(
          progress: progress,
          accentColor: accentColor,
          trackColor: accentColor.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

/// Mini real chest graphic indicator with luminous aura.
class _FacMiniRewardChest extends StatelessWidget {
  const _FacMiniRewardChest({
    required this.accentColor,
  });

  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final String asset = _facilityChestAssetFor(accentColor);
    return Container(
      width: 14,
      height: 14,
      margin: const EdgeInsets.only(right: 3),
      decoration: BoxDecoration(
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accentColor.withValues(alpha: 0.45),
            blurRadius: 6,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        errorBuilder: (
          BuildContext context,
          Object error,
          StackTrace? stackTrace,
        ) =>
            const Text('🎁', style: TextStyle(fontSize: 9)),
      ),
    );
  }
}

/// Aion-2 Frosted Glass Tesis Kartı — Tactile Spring + Luminous Neon Glow.
class FacHubFacilityCard extends StatefulWidget {
  const FacHubFacilityCard({
    super.key,
    required this.animationIndex,
    required this.icon,
    required this.name,
    required this.isUnlocked,
    this.canUnlock = false,
    required this.footer,
    required this.accentColor,
    required this.onTap,
  });

  final int animationIndex;
  final String icon;
  final String name;
  final bool isUnlocked;
  final bool canUnlock;
  final String footer;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  State<FacHubFacilityCard> createState() => _FacHubFacilityCardState();
}

class _FacHubFacilityCardState extends State<FacHubFacilityCard> {
  bool _visible = false;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    final int safeIndex = widget.animationIndex.clamp(0, 30);
    final int delayMs = 35 * safeIndex;
    Future<void>.delayed(Duration(milliseconds: delayMs), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final _FacilityCardMetadata meta =
        _FacilityCardMetadata.fromFooter(widget.footer);

    final Color borderColor = widget.isUnlocked
        ? widget.accentColor.withValues(alpha: 0.65)
        : widget.canUnlock
        ? AppColors.toxicNeon.withValues(alpha: 0.60)
        : AppColors.mutedTitanium.withValues(alpha: 0.24);

    final Color glowColor = widget.isUnlocked
        ? widget.accentColor
        : widget.canUnlock
        ? AppColors.toxicNeon
        : Colors.transparent;

    final Color splashAccent = widget.isUnlocked
        ? widget.accentColor
        : widget.canUnlock
        ? AppColors.toxicNeon
        : AppColors.mutedTitanium;

    final String bgAsset = _facilityBackgroundFor(
      name: widget.name,
      icon: widget.icon,
    );

    return SingleMotionBuilder(
      value: _visible ? 1.0 : 0.0,
      motion: const Motion.smoothSpring(duration: Duration(milliseconds: 450)),
      builder: (BuildContext context, double enter, Widget? child) {
        return Opacity(
          opacity: enter.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - enter) * 12),
            child: child,
          ),
        );
      },
      child: SingleMotionBuilder(
        value: _pressed ? 0.96 : 1.0,
        motion: const Motion.snappySpring(
          duration: Duration(milliseconds: 160),
        ),
        builder: (BuildContext context, double scale, Widget? child) {
          return Transform.scale(scale: scale, child: child);
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: _pressed ? 0.28 : 0.42),
                blurRadius: _pressed ? 6 : 12,
                offset: Offset(0, _pressed ? 2 : 4),
              ),
              if (glowColor != Colors.transparent)
                BoxShadow(
                  color: glowColor.withValues(alpha: _pressed ? 0.32 : 0.18),
                  blurRadius: _pressed ? 8 : 16,
                  spreadRadius: _pressed ? -1 : 0,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
                  border: Border.all(
                    color: borderColor,
                    width: widget.isUnlocked
                        ? 1.4
                        : (widget.canUnlock ? 1.2 : 1.0),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      widget.isUnlocked
                          ? widget.accentColor.withValues(alpha: 0.16)
                          : widget.canUnlock
                          ? AppColors.toxicNeon.withValues(alpha: 0.12)
                          : AppColors.bgDeep.withValues(alpha: 0.88),
                      widget.isUnlocked
                          ? AppColors.bgCardElevated.withValues(alpha: 0.88)
                          : widget.canUnlock
                          ? AppColors.spaceNavy.withValues(alpha: 0.86)
                          : AppColors.carbonVoid.withValues(alpha: 0.94),
                      AppColors.carbonVoid.withValues(alpha: 0.97),
                    ],
                    stops: const <double>[0.0, 0.45, 1.0],
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      widget.onTap();
                    },
                    onTapDown: (_) {
                      if (mounted) setState(() => _pressed = true);
                    },
                    onTapUp: (_) {
                      if (mounted) setState(() => _pressed = false);
                    },
                    onTapCancel: () {
                      if (mounted) setState(() => _pressed = false);
                    },
                    splashColor: splashAccent.withValues(alpha: 0.16),
                    highlightColor: splashAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(FacilitiesUi.radiusMd),
                    child: MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.25,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 124),
                        padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
                        child: Stack(
                          children: <Widget>[
                            // Real Aion Environment Background Art Texture
                            Positioned.fill(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  FacilitiesUi.radiusMd,
                                ),
                                child: Opacity(
                                  opacity: widget.isUnlocked ? 0.14 : 0.08,
                                  child: Image.asset(
                                    bgAsset,
                                    fit: BoxFit.cover,
                                    errorBuilder: (
                                      BuildContext context,
                                      Object error,
                                      StackTrace? stackTrace,
                                    ) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                            // Top Edge Specular Rim Sheen
                            Positioned(
                              top: 0,
                              left: 6,
                              right: 6,
                              height: 1,
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: <Color>[
                                        Colors.transparent,
                                        (widget.isUnlocked
                                                ? widget.accentColor
                                                : widget.canUnlock
                                                ? AppColors.toxicNeon
                                                : Colors.white)
                                            .withValues(alpha: 0.35),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Corner Runic Glow
                            if (widget.isUnlocked)
                              Positioned(
                                right: -16,
                                top: -16,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: <Color>[
                                          widget.accentColor.withValues(
                                            alpha: 0.28,
                                          ),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else if (widget.canUnlock)
                              Positioned(
                                right: -14,
                                top: -14,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 58,
                                    height: 58,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: <Color>[
                                          AppColors.toxicNeon.withValues(
                                            alpha: 0.24,
                                          ),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Main Facility Card Content
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: widget.isUnlocked
                                              ? <Color>[
                                                  widget.accentColor.withValues(
                                                    alpha: 0.24,
                                                  ),
                                                  widget.accentColor.withValues(
                                                    alpha: 0.08,
                                                  ),
                                                ]
                                              : widget.canUnlock
                                              ? <Color>[
                                                  AppColors.toxicNeon.withValues(
                                                    alpha: 0.22,
                                                  ),
                                                  AppColors.spaceNavy.withValues(
                                                    alpha: 0.50,
                                                  ),
                                                ]
                                              : <Color>[
                                                  AppColors.darkObsidian
                                                      .withValues(alpha: 0.60),
                                                  AppColors.bgDeep.withValues(
                                                    alpha: 0.40,
                                                  ),
                                                ],
                                        ),
                                        border: Border.all(
                                          color: widget.isUnlocked
                                              ? widget.accentColor.withValues(
                                                  alpha: 0.45,
                                                )
                                              : widget.canUnlock
                                              ? AppColors.toxicNeon.withValues(
                                                  alpha: 0.40,
                                                )
                                              : AppColors.mutedTitanium
                                                  .withValues(alpha: 0.22),
                                          width: 0.9,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        widget.icon.isEmpty ? '🏭' : widget.icon,
                                        style: const TextStyle(fontSize: 18),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4.5,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        color: AppColors.spaceNavy.withValues(
                                          alpha: 0.75,
                                        ),
                                        border: Border.all(
                                          color: (widget.isUnlocked
                                                  ? widget.accentColor
                                                  : AppColors.accentCyan)
                                              .withValues(alpha: 0.40),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: const Text(
                                        '3D',
                                        style: TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.accentCyan,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: _FacStatusPill(
                                        label: widget.isUnlocked
                                            ? '● Aktif'
                                            : widget.canUnlock
                                            ? '⚡ Açılabilir'
                                            : '🔒 Kilitli',
                                        color: widget.isUnlocked
                                            ? AppColors.toxicNeon
                                            : widget.canUnlock
                                            ? AppColors.liquidGold
                                            : AppColors.mutedTitanium,
                                        isShimmering: widget.isUnlocked ||
                                            widget.canUnlock,
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 6,
                                  ),
                                  child: Text(
                                    widget.name.isEmpty ? 'Tesis' : widget.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                      height: 1.18,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6.5,
                                    vertical: 3.5,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: widget.isUnlocked
                                        ? widget.accentColor.withValues(
                                            alpha: 0.10,
                                          )
                                        : widget.canUnlock
                                        ? AppColors.toxicNeon.withValues(
                                            alpha: 0.10,
                                          )
                                        : AppColors.bgDeep.withValues(
                                            alpha: 0.55,
                                          ),
                                    border: Border.all(
                                      color: widget.isUnlocked
                                          ? widget.accentColor.withValues(
                                              alpha: 0.28,
                                            )
                                          : widget.canUnlock
                                          ? AppColors.toxicNeon.withValues(
                                              alpha: 0.32,
                                            )
                                          : AppColors.mutedTitanium.withValues(
                                              alpha: 0.18,
                                            ),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      if (meta.isReady) ...<Widget>[
                                        _FacMiniRewardChest(
                                          accentColor: widget.accentColor,
                                        ),
                                      ] else if (widget.isUnlocked) ...<Widget>[
                                        _FacProductionRateGauge(
                                          rate: meta.rate,
                                          accentColor: widget.accentColor,
                                          isProducing: meta.isProducing,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Flexible(
                                        child: Text(
                                          widget.footer.isEmpty
                                              ? (widget.isUnlocked
                                                  ? 'Hazır'
                                                  : 'Kilitli')
                                              : widget.footer,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: widget.isUnlocked
                                                ? widget.accentColor
                                                : widget.canUnlock
                                                ? AppColors.toxicNeon
                                                : AppColors.mutedTitanium,
                                            letterSpacing: 0.2,
                                          ),
                                        ),
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

/// Shimmering Aion Status Badge with loop lifecycle and memory safety.
class _FacStatusPill extends StatefulWidget {
  const _FacStatusPill({
    required this.label,
    required this.color,
    this.isShimmering = false,
  });

  final String label;
  final Color color;
  final bool isShimmering;

  @override
  State<_FacStatusPill> createState() => _FacStatusPillState();
}

class _FacStatusPillState extends State<_FacStatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.isShimmering) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _FacStatusPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isShimmering != oldWidget.isShimmering) {
      if (widget.isShimmering) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget pillContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FacilitiesUi.radiusPill),
        color: widget.color.withValues(alpha: 0.14),
        border: Border.all(
          color: widget.color.withValues(alpha: 0.48),
          width: 0.85,
        ),
        boxShadow: widget.isShimmering
            ? <BoxShadow>[
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.28),
                  blurRadius: 6,
                  spreadRadius: -1,
                ),
              ]
            : null,
      ),
      child: Text(
        widget.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: widget.color,
          letterSpacing: 0.25,
        ),
      ),
    );

    if (!widget.isShimmering) {
      return pillContent;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double value = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (Rect bounds) {
            return LinearGradient(
              begin: Alignment(-2.0 + 4.0 * value, -0.3),
              end: Alignment(-1.0 + 4.0 * value, 0.3),
              colors: const <Color>[
                Colors.white38,
                Colors.white,
                Colors.white38,
              ],
              stops: const <double>[0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: pillContent,
    );
  }
}

Color facTierAccent(int tier) {
  switch (tier) {
    case 1:
      return AppColors.liquidGold;
    case 2:
      return AppColors.toxicNeon;
    case 3:
      return AppColors.cyberFuchsia;
    case 4:
      return AppColors.accentCyan;
    default:
      return AppColors.mutedTitanium;
  }
}

List<Widget> facBuildFacilityCardRows({
  required List<Widget Function(int index)> cardBuilder,
}) {
  final List<Widget> rows = <Widget>[];
  for (int i = 0; i < cardBuilder.length; i += 2) {
    rows.add(
      FacFacilityCardRow(
        left: cardBuilder[i](i),
        right: i + 1 < cardBuilder.length ? cardBuilder[i + 1](i + 1) : null,
      ),
    );
  }
  return rows;
}
