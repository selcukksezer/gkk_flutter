import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/aion_asset_illustrations.dart';
import '../../components/common/item_icon_view.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';
import 'loot_chest_theme.dart';
import 'loot_models.dart';

// =============================================================================
// 1. DATA MODELS & LAYOUT UTILITIES
// =============================================================================

/// Requirement specifications for locked chests requiring dungeon / boss keys.
class LootKeyRequirement {
  const LootKeyRequirement({
    required this.keyId,
    required this.keyName,
    this.icon = '🔑',
    required this.requiredQuantity,
    required this.ownedQuantity,
    this.keyRarity = 'rare',
  });

  final String keyId;
  final String keyName;
  final String icon;
  final int requiredQuantity;
  final int ownedQuantity;
  final String keyRarity;

  bool get isSatisfied => ownedQuantity >= requiredQuantity;
  int get missingCount => math.max(0, requiredQuantity - ownedQuantity);
}

/// Legacy grid painter preserved for backward compatibility and tech-fantasy backdrop.
class LootChestGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1.0;
    const double cell = 20;
    for (double x = 0; x <= size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LootBannerLayout {
  const _LootBannerLayout({
    required this.bannerWidth,
    required this.textScale,
    this.heightOverride,
  });

  final double bannerWidth;
  final double textScale;
  final double? heightOverride;

  bool get tight => bannerWidth < 360;
  bool get veryTight => bannerWidth < 330;
  bool get compact => bannerWidth < 390;

  double get horizontalInset => veryTight ? 12 : (tight ? 14 : AppSpacing.base);
  double get verticalInset =>
      veryTight ? 10 : (tight ? AppSpacing.md : (compact ? AppSpacing.base : AppSpacing.lg));
  double get contentRight =>
      veryTight ? 108 : (tight ? 120 : (compact ? 138 : 168));
  double get imageWidth =>
      veryTight ? 160 : (tight ? 180 : (compact ? 220 : 260));
  double get imageRight =>
      veryTight ? -16 : (tight ? -24 : (compact ? -28 : -42));
  double get imageTopBottom =>
      veryTight ? -20 : (tight ? -28 : (compact ? -32 : -44));
  double get titleSize => tight ? 18 : (compact ? 20 : 24);
  double get subtitleSize => tight ? 10 : (compact ? 11 : 12);
  double get priceInset => tight ? AppSpacing.md : (compact ? 14 : AppSpacing.base);

  double get bannerHeight {
    if (heightOverride != null) return heightOverride!;
    final double scaleBoost = (textScale.clamp(1.0, 1.4) - 1.0) * 36;
    if (tight) return 224 + scaleBoost;
    if (compact) return 220 + scaleBoost;
    return 232 + scaleBoost;
  }
}

// =============================================================================
// 2. HIGH-FIDELITY VECTOR SHADERS & PAINTERS
// =============================================================================

/// 2027 Aion 2 Mobile Burning Purple Runic Chains Painter for Eternal Tier.
class _EternalRunicChainsPainter extends CustomPainter {
  const _EternalRunicChainsPainter({
    required this.glowColor,
    required this.pulse,
  });

  final Color glowColor;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Paint chainGlow = Paint()
      ..color = glowColor.withValues(alpha: (0.45 + pulse * 0.35).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final Paint chainCore = Paint()
      ..color = const Color(0xFFE879F9).withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Diagonal crossing runic chain paths
    final Path path1 = Path()
      ..moveTo(-10, size.height * 0.25)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.15,
        size.width * 0.65,
        size.height * 0.85,
        size.width + 10,
        size.height * 0.75,
      );

    final Path path2 = Path()
      ..moveTo(-10, size.height * 0.75)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.85,
        size.width * 0.65,
        size.height * 0.15,
        size.width + 10,
        size.height * 0.25,
      );

    canvas.drawPath(path1, chainGlow);
    canvas.drawPath(path1, chainCore);
    canvas.drawPath(path2, chainGlow);
    canvas.drawPath(path2, chainCore);

    // Runic link pulses
    final Paint runeMark = Paint()
      ..color = Colors.white.withValues(alpha: (0.60 + pulse * 0.40).clamp(0.0, 1.0))
      ..style = PaintingStyle.fill;

    for (double t = 0.2; t <= 0.8; t += 0.2) {
      final double x1 = size.width * t;
      final double y1 = size.height * (0.25 + (t - 0.2) * 0.8);
      canvas.drawCircle(Offset(x1, y1), 2.2, runeMark);

      final double x2 = size.width * t;
      final double y2 = size.height * (0.75 - (t - 0.2) * 0.8);
      canvas.drawCircle(Offset(x2, y2), 2.2, runeMark);
    }
  }

  @override
  bool shouldRepaint(covariant _EternalRunicChainsPainter oldDelegate) {
    return oldDelegate.pulse != pulse || oldDelegate.glowColor != glowColor;
  }
}

/// 2027 Aion 2 Holographic Foil Shimmer Sweep Painter.
class _HolographicShimmerPainter extends CustomPainter {
  const _HolographicShimmerPainter({
    required this.progress,
    required this.tierColor,
  });

  final double progress;
  final Color tierColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final double sweepOffset = (progress * 2.4 - 0.7) * diagonal;

    final Paint shimmerPaint = Paint()
      ..blendMode = BlendMode.screen
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        transform: const GradientRotation(math.pi / 4),
        colors: <Color>[
          Colors.transparent,
          tierColor.withValues(alpha: 0.05),
          AppColors.accentCyan.withValues(alpha: 0.25),
          AppColors.goldLight.withValues(alpha: 0.35),
          AppColors.accentPurple.withValues(alpha: 0.30),
          Colors.white.withValues(alpha: 0.45),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.2, 0.4, 0.5, 0.6, 0.75, 1.0],
      ).createShader(
        Rect.fromLTWH(sweepOffset - 80, sweepOffset - 80, 160, 160),
      );

    canvas.drawRect(Offset.zero & size, shimmerPaint);
  }

  @override
  bool shouldRepaint(covariant _HolographicShimmerPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.tierColor != tierColor;
  }
}

/// Multi-layered animated atmospheric rarity halo surrounding 3D chests.
class LootRarityHaloPainter extends CustomPainter {
  const LootRarityHaloPainter({
    required this.color,
    required this.pulse,
    required this.rotation,
    this.glyphs = const <String>['ᛟ', 'ᚱ', 'ᚦ'],
  });

  final Color color;
  final double pulse;
  final double rotation;
  final List<String> glyphs;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = math.min(size.width, size.height) * 0.46;

    // 1. Diffuse Ambient Glow Core
    final Paint glowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          color.withValues(alpha: (0.42 + 0.22 * pulse).clamp(0.0, 1.0)),
          color.withValues(alpha: (0.18 + 0.12 * pulse).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.35));
    canvas.drawCircle(center, radius * 1.35, glowPaint);

    // 2. Arcane Runic Orbit Rings
    final Paint ringPaint = Paint()
      ..color = color.withValues(alpha: (0.35 + 0.25 * pulse).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, radius, ringPaint);

    final Paint dashedRingPaint = Paint()
      ..color = color.withValues(alpha: (0.20 + 0.15 * pulse).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawCircle(center, radius * 0.82, dashedRingPaint);

    // 3. Runic Notches & Glyphs along Orbit
    const int count = 12;
    const double step = (math.pi * 2) / count;
    final Paint tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: (0.40 + 0.35 * pulse).clamp(0.0, 1.0))
      ..strokeWidth = 1.4;

    for (int i = 0; i < count; i++) {
      final double angle = rotation + (i * step);
      final double innerR = (i % 3 == 0) ? radius - 6 : radius - 3;
      final double outerR = (i % 3 == 0) ? radius + 6 : radius + 3;

      final Offset p1 = Offset(
        center.dx + math.cos(angle) * innerR,
        center.dy + math.sin(angle) * innerR,
      );
      final Offset p2 = Offset(
        center.dx + math.cos(angle) * outerR,
        center.dy + math.sin(angle) * outerR,
      );
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LootRarityHaloPainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.rotation != rotation ||
        oldDelegate.color != color;
  }
}

/// AAA high-fantasy vector metallic card frame with beveled corner ornaments & light sheens.
class LootVectorFramePainter extends CustomPainter {
  const LootVectorFramePainter({
    required this.borderColor,
    required this.accentColor,
    this.cornerSize = 14.0,
    this.strokeWidth = 1.5,
    this.showCornerRivets = true,
  });

  final Color borderColor;
  final Color accentColor;
  final double cornerSize;
  final double strokeWidth;
  final bool showCornerRivets;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2),
      const Radius.circular(AppSpacing.radiusXl),
    );

    // 1. Base Beveled Border Frame
    final Paint borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawRRect(rrect, borderPaint);

    // 2. Specular Top Light Sheen
    final Paint sheenPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.topRight,
        colors: <Color>[
          Colors.transparent,
          accentColor.withValues(alpha: 0.85),
          Colors.white.withValues(alpha: 0.95),
          accentColor.withValues(alpha: 0.85),
          Colors.transparent,
        ],
        stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, strokeWidth * 2))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.2;

    final Path topEdge = Path()
      ..moveTo(AppSpacing.radiusXl, strokeWidth / 2)
      ..lineTo(size.width - AppSpacing.radiusXl, strokeWidth / 2);
    canvas.drawPath(topEdge, sheenPaint);

    // 3. Ornamental Metallic Corner Brackets
    final Paint bracketPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 1.4;

    // Top-Left Corner
    final Path tlPath = Path()
      ..moveTo(4, cornerSize + 4)
      ..lineTo(4, 12)
      ..arcToPoint(const Offset(12, 4), radius: const Radius.circular(8))
      ..lineTo(cornerSize + 4, 4);
    canvas.drawPath(tlPath, bracketPaint);

    // Top-Right Corner
    final Path trPath = Path()
      ..moveTo(size.width - cornerSize - 4, 4)
      ..lineTo(size.width - 12, 4)
      ..arcToPoint(Offset(size.width - 4, 12), radius: const Radius.circular(8))
      ..lineTo(size.width - 4, cornerSize + 4);
    canvas.drawPath(trPath, bracketPaint);

    // Bottom-Left Corner
    final Path blPath = Path()
      ..moveTo(4, size.height - cornerSize - 4)
      ..lineTo(4, size.height - 12)
      ..arcToPoint(Offset(12, size.height - 4), radius: const Radius.circular(8))
      ..lineTo(cornerSize + 4, size.height - 4);
    canvas.drawPath(blPath, bracketPaint);

    // Bottom-Right Corner
    final Path brPath = Path()
      ..moveTo(size.width - cornerSize - 4, size.height - 4)
      ..lineTo(size.width - 12, size.height - 4)
      ..arcToPoint(Offset(size.width - 4, size.height - 12), radius: const Radius.circular(8))
      ..lineTo(size.width - 4, size.height - cornerSize - 4);
    canvas.drawPath(brPath, bracketPaint);

    // 4. Corner Rivet Dots
    if (showCornerRivets) {
      final Paint rivetPaint = Paint()
        ..color = accentColor.withValues(alpha: 0.85)
        ..style = PaintingStyle.fill;
      final Paint rivetGlow = Paint()
        ..color = Colors.white.withValues(alpha: 0.95)
        ..style = PaintingStyle.fill;

      const double inset = 10.0;
      final List<Offset> rivets = <Offset>[
        const Offset(inset, inset),
        Offset(size.width - inset, inset),
        Offset(inset, size.height - inset),
        Offset(size.width - inset, size.height - inset),
      ];

      for (final Offset r in rivets) {
        canvas.drawCircle(r, 2.0, rivetPaint);
        canvas.drawCircle(r, 0.9, rivetGlow);
      }
    }
  }

  @override
  bool shouldRepaint(covariant LootVectorFramePainter oldDelegate) {
    return oldDelegate.borderColor != borderColor ||
        oldDelegate.accentColor != accentColor ||
        oldDelegate.cornerSize != cornerSize ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.showCornerRivets != showCornerRivets;
  }
}

/// Metallic crossing chains with heavy padlock for locked chests.
class LootLockChainsPainter extends CustomPainter {
  const LootLockChainsPainter({
    required this.lockColor,
    required this.pulse,
  });

  final Color lockColor;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Offset center = Offset(size.width / 2, size.height / 2);

    // Crossing Heavy Chain Links
    final Paint chainGlow = Paint()
      ..color = lockColor.withValues(alpha: (0.35 + pulse * 0.25).clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final Paint chainCore = Paint()
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final Path d1 = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height);
    final Path d2 = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height);

    canvas.drawPath(d1, chainGlow);
    canvas.drawPath(d1, chainCore);
    canvas.drawPath(d2, chainGlow);
    canvas.drawPath(d2, chainCore);

    // Center Heavy Padlock
    final double lockW = math.min(size.width, size.height) * 0.34;
    final double lockH = lockW * 1.15;
    final Rect bodyRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + lockH * 0.12),
      width: lockW,
      height: lockH * 0.76,
    );

    // Padlock Shackle (Arch)
    final Paint shacklePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = lockW * 0.16
      ..strokeCap = StrokeCap.round;

    final Path shackle = Path()
      ..moveTo(center.dx - lockW * 0.28, center.dy + lockH * 0.05)
      ..lineTo(center.dx - lockW * 0.28, center.dy - lockH * 0.26)
      ..arcToPoint(
        Offset(center.dx + lockW * 0.28, center.dy - lockH * 0.26),
        radius: Radius.circular(lockW * 0.28),
      )
      ..lineTo(center.dx + lockW * 0.28, center.dy + lockH * 0.05);
    canvas.drawPath(shackle, shacklePaint);

    // Padlock Body
    final Paint bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          const Color(0xFF334155),
          const Color(0xFF0F172A),
          lockColor.withValues(alpha: 0.6),
        ],
      ).createShader(bodyRect);

    final RRect bodyRRect = RRect.fromRectAndRadius(
      bodyRect,
      const Radius.circular(AppSpacing.radiusSm),
    );
    canvas.drawRRect(bodyRRect, bodyPaint);

    final Paint bodyBorder = Paint()
      ..color = lockColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRRect(bodyRRect, bodyBorder);

    // Keyhole
    final Paint keyholePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;
    final Offset keyholeCenter = Offset(center.dx, center.dy + lockH * 0.10);
    canvas.drawCircle(keyholeCenter, lockW * 0.08, keyholePaint);

    final Path keyholeSlot = Path()
      ..moveTo(keyholeCenter.dx - lockW * 0.04, keyholeCenter.dy)
      ..lineTo(keyholeCenter.dx - lockW * 0.06, keyholeCenter.dy + lockH * 0.14)
      ..lineTo(keyholeCenter.dx + lockW * 0.06, keyholeCenter.dy + lockH * 0.14)
      ..lineTo(keyholeCenter.dx + lockW * 0.04, keyholeCenter.dy)
      ..close();
    canvas.drawPath(keyholeSlot, keyholePaint);
  }

  @override
  bool shouldRepaint(covariant LootLockChainsPainter oldDelegate) {
    return oldDelegate.lockColor != lockColor || oldDelegate.pulse != pulse;
  }
}

// =============================================================================
// 3. AUDIO-TACTILE HAPTIC CONTROLLER
// =============================================================================

/// Tactile Audio-Visual Rarity Chime Controller.
abstract final class LootRarityChime {
  static Future<void> trigger(BuildContext context, LootChestTier tier) async {
    try {
      switch (tier) {
        case LootChestTier.common:
          await HapticFeedback.selectionClick();
        case LootChestTier.rare:
          await HapticFeedback.lightImpact();
        case LootChestTier.heroic:
          await HapticFeedback.mediumImpact();
        case LootChestTier.fabled:
          await HapticFeedback.heavyImpact();
        case LootChestTier.eternal:
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 70));
          await HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }
}

// =============================================================================
// 4. ANIMATED RARITY HALO WIDGET
// =============================================================================

/// Animated glowing rarity halo widget surrounding chests or items.
class LootChestRarityHalo extends StatefulWidget {
  const LootChestRarityHalo({
    super.key,
    required this.tier,
    this.size = 180,
    this.customColor,
  });

  final LootChestTier tier;
  final double size;
  final Color? customColor;

  @override
  State<LootChestRarityHalo> createState() => _LootChestRarityHaloState();
}

class _LootChestRarityHaloState extends State<LootChestRarityHalo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color haloColor = widget.customColor ?? widget.tier.accentColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        final double pulse = math.sin(_controller.value * math.pi * 2) * 0.5 + 0.5;
        final double rotation = _controller.value * math.pi * 2;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: LootRarityHaloPainter(
              color: haloColor,
              pulse: pulse,
              rotation: rotation,
              glyphs: widget.tier.runicGlyphs,
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// 5. LOCK COUNTDOWN TIMER & STATUS BADGE
// =============================================================================

/// Live lock countdown timer badge with automatic tick & unlock event.
class LootLockCountdownTimer extends StatefulWidget {
  const LootLockCountdownTimer({
    super.key,
    required this.unlockTime,
    this.isLocked = true,
    this.onUnlocked,
    this.accentColor,
    this.compact = false,
  });

  final DateTime? unlockTime;
  final bool isLocked;
  final VoidCallback? onUnlocked;
  final Color? accentColor;
  final bool compact;

  @override
  State<LootLockCountdownTimer> createState() => _LootLockCountdownTimerState();
}

class _LootLockCountdownTimerState extends State<LootLockCountdownTimer> {
  Timer? _timer;
  bool _notifiedUnlocked = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void didUpdateWidget(covariant LootLockCountdownTimer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.unlockTime != oldWidget.unlockTime ||
        widget.isLocked != oldWidget.isLocked) {
      _notifiedUnlocked = false;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final Duration remaining = _getRemaining();
      if (remaining <= Duration.zero && !_notifiedUnlocked) {
        _notifiedUnlocked = true;
        widget.onUnlocked?.call();
      }
      setState(() {});
    });
  }

  Duration _getRemaining() {
    if (widget.unlockTime == null) return Duration.zero;
    final Duration diff = widget.unlockTime!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final int hours = d.inHours;
    final int minutes = d.inMinutes % 60;
    final int seconds = d.inSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final Duration remaining = _getRemaining();
    final bool isReady = remaining <= Duration.zero && !widget.isLocked;

    final Color badgeColor = isReady
        ? AppColors.success
        : (widget.accentColor ?? AppColors.warning);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? AppSpacing.xs + 2 : AppSpacing.sm,
        vertical: widget.compact ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isReady
            ? AppColors.success.withValues(alpha: 0.16)
            : Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.65),
          width: 1.0,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: badgeColor.withValues(alpha: 0.20),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            isReady ? Icons.lock_open_rounded : Icons.timer_outlined,
            size: widget.compact ? 12 : 14,
            color: badgeColor,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            isReady ? 'AÇILABİLİR' : 'KİLİTLİ · ${_formatDuration(remaining)}',
            style: AppTextStyles.micro.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 6. KEY REQUIREMENT BADGE WIDGET
// =============================================================================

/// Displays key consumption requirements (e.g. 1x Gold Key) with satisfaction status.
class LootKeyRequirementBadge extends StatelessWidget {
  const LootKeyRequirementBadge({
    super.key,
    required this.requirement,
    this.compact = false,
  });

  final LootKeyRequirement requirement;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool ok = requirement.isSatisfied;
    final Color color = ok ? AppColors.success : AppColors.warning;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xs + 2 : AppSpacing.sm,
        vertical: compact ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: ok
            ? AppColors.success.withValues(alpha: 0.14)
            : AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.55),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(requirement.icon, style: TextStyle(fontSize: compact ? 10 : 12)),
          const SizedBox(width: AppSpacing.xs),
          Text(
            compact
                ? '${requirement.ownedQuantity}/${requirement.requiredQuantity}'
                : '${requirement.keyName}: ${requirement.ownedQuantity}/${requirement.requiredQuantity}',
            style: AppTextStyles.micro.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!ok) ...<Widget>[
            const SizedBox(width: AppSpacing.xs),
            Icon(Icons.warning_amber_rounded, size: compact ? 10 : 12, color: color),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// 7. ANIMATED 3D CHEST ILLUSTRATION WITH VECTOR FALLBACK
// =============================================================================

/// Floating 3D chest illustration with ambient rarity halo and locked overlay.
class Loot3DChestIllustration extends StatefulWidget {
  const Loot3DChestIllustration({
    super.key,
    required this.theme,
    this.size = 140,
    this.isLocked = false,
    this.enableFloatAnimation = true,
    this.showHalo = true,
    this.onTap,
  });

  final LootChestTheme theme;
  final double size;
  final bool isLocked;
  final bool enableFloatAnimation;
  final bool showHalo;
  final VoidCallback? onTap;

  @override
  State<Loot3DChestIllustration> createState() => _Loot3DChestIllustrationState();
}

class _Loot3DChestIllustrationState extends State<Loot3DChestIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );
    if (widget.enableFloatAnimation) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant Loot3DChestIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enableFloatAnimation != oldWidget.enableFloatAnimation) {
      if (widget.enableFloatAnimation) {
        _controller.repeat(reverse: true);
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
    final LootChestTheme theme = widget.theme;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onTap?.call();
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          final double floatVal = widget.enableFloatAnimation
              ? math.sin(_controller.value * math.pi) * 4.5
              : 0.0;
          final double tiltX = widget.enableFloatAnimation
              ? math.cos(_controller.value * math.pi) * 0.02
              : 0.0;

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: <Widget>[
                // 1. Rarity Halo Behind Chest
                if (widget.showHalo)
                  Positioned.fill(
                    child: LootChestRarityHalo(
                      tier: theme.tier,
                      size: widget.size * 1.25,
                      customColor: theme.accentColor,
                    ),
                  ),

                // 2. Floating 3D Chest Art
                Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002)
                    ..translate(0.0, floatVal)
                    ..rotateX(tiltX),
                  child: Image.asset(
                    theme.assetPath,
                    width: widget.size,
                    height: widget.size,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => AionChestIllustration(
                      tier: theme.tier,
                      size: widget.size * 0.9,
                      showGlow: true,
                    ),
                  ),
                ),

                // 3. Locked Void Overlay & Heavy Padlock Chains
                if (widget.isLocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.45),
                      ),
                      child: CustomPaint(
                        painter: LootLockChainsPainter(
                          lockColor: theme.borderColor,
                          pulse: _controller.value,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// 8. AAA TACTILE OPEN CTA BUTTON
// =============================================================================

/// Luxury AAA Open CTA button featuring state feedback, haptic impacts & currency icons.
class LootChestOpenButton extends StatefulWidget {
  const LootChestOpenButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.isLocked = false,
    this.isFree = false,
    this.priceLabel,
    this.priceIcon = Icons.paid,
    this.priceColor = AppColors.gold,
    this.accentColor,
    this.label = 'KASA AÇ',
    this.sublabel,
    this.keySatisfied = true,
    this.fullWidth = true,
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isLocked;
  final bool isFree;
  final String? priceLabel;
  final IconData priceIcon;
  final Color priceColor;
  final Color? accentColor;
  final String label;
  final String? sublabel;
  final bool keySatisfied;
  final bool fullWidth;

  @override
  State<LootChestOpenButton> createState() => _LootChestOpenButtonState();
}

class _LootChestOpenButtonState extends State<LootChestOpenButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool canPress = !widget.isLoading && !widget.isLocked && widget.keySatisfied;
    final Color baseAccent = widget.accentColor ?? AppColors.gold;
    final Color buttonColor = widget.isFree
        ? AppColors.success
        : (canPress ? baseAccent : AppColors.borderDefault);

    final Widget buttonContent = AnimatedScale(
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: canPress
                ? <Color>[
                    buttonColor,
                    buttonColor.withValues(alpha: 0.85),
                  ]
                : <Color>[
                    AppColors.bgCardElevated,
                    AppColors.bgSurface,
                  ],
          ),
          border: Border.all(
            color: canPress
                ? Colors.white.withValues(alpha: 0.6)
                : AppColors.borderDefault,
            width: 1.2,
          ),
          boxShadow: canPress
              ? <BoxShadow>[
                  BoxShadow(
                    color: buttonColor.withValues(alpha: 0.45),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onHighlightChanged: (bool h) => setState(() => _pressed = h),
            onTap: canPress
                ? () {
                    HapticFeedback.mediumImpact();
                    widget.onPressed?.call();
                  }
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
              child: Center(
                child: widget.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.black,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (widget.isFree) ...<Widget>[
                            const Icon(Icons.stars_rounded, size: 18, color: Colors.black),
                            const SizedBox(width: AppSpacing.xs),
                          ] else if (widget.isLocked) ...<Widget>[
                            const Icon(Icons.lock_rounded, size: 16, color: Colors.white60),
                            const SizedBox(width: AppSpacing.xs),
                          ] else if (widget.priceLabel != null) ...<Widget>[
                            Icon(widget.priceIcon, size: 16, color: Colors.black87),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              widget.priceLabel!,
                              style: AppTextStyles.titleBold.copyWith(
                                color: Colors.black87,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              width: 1.0,
                              height: 16,
                              color: Colors.black.withValues(alpha: 0.25),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Text(
                            widget.isFree
                                ? 'ÜCRETSİZ 1x AÇ'
                                : (widget.isLocked ? 'KİLİTLİ' : widget.label),
                            style: AppTextStyles.titleBold.copyWith(
                              color: canPress ? Colors.black : AppColors.textTertiary,
                              fontSize: 13,
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
    );

    return widget.fullWidth
        ? SizedBox(width: double.infinity, child: buttonContent)
        : buttonContent;
  }
}

// =============================================================================
// 9. DEDICATED FULL CHEST CARD WIDGET
// =============================================================================

/// Comprehensive AAA Game Studio Chest Card Widget.
/// Includes vector metallic frame, floating 3D chest, rarity halo, lock countdowns & key badges.
class LootChestCard extends StatelessWidget {
  const LootChestCard({
    super.key,
    required this.box,
    this.themeOverride,
    this.onOpen,
    this.onOpen10x,
    this.onDropRatesTap,
    this.isOpening = false,
    this.isLocked = false,
    this.unlockTime,
    this.keyRequirement,
    this.isFreeSummon = false,
    this.width,
    this.height,
  });

  final LootBoxView box;
  final LootChestTheme? themeOverride;
  final VoidCallback? onOpen;
  final VoidCallback? onOpen10x;
  final VoidCallback? onDropRatesTap;
  final bool isOpening;
  final bool isLocked;
  final DateTime? unlockTime;
  final LootKeyRequirement? keyRequirement;
  final bool isFreeSummon;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final int themeIndex = lootThemeIndexForBox(box);
    final LootChestTheme theme = themeOverride ??
        resolveLootChestTheme(
          boxId: box.id,
          artAsset: box.artAsset,
          themeIndex: themeIndex,
          themeId: box.themeId,
        );

    final String title = lootBoxDisplayName(
      box: box,
      theme: theme,
      themeIndex: themeIndex,
    );
    final String subtitle = lootBoxSubtitle(
      box: box,
      theme: theme,
      themeIndex: themeIndex,
    );

    final Color currencyColor =
        box.currencyType == 'gems' ? AppColors.accentCyan : AppColors.gold;
    final IconData currencyIcon =
        box.currencyType == 'gems' ? Icons.diamond : Icons.paid;

    final int multiPrice = (box.price * 9); // 10% discount for 10x

    return Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        gradient: RadialGradient(
          center: const Alignment(0.4, -0.2),
          radius: 1.4,
          colors: <Color>[theme.radialCenter, theme.radialEdge],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: theme.glowColor,
            blurRadius: 22,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        child: Stack(
          children: <Widget>[
            // 1. Grid Painter & Eternal Chains
            CustomPaint(painter: LootChestGridPainter()),
            if (theme.isEternal)
              _EternalRunicChainsStaticOverlay(glowColor: theme.tier.chainColor),

            // 2. Vector Metallic Beveled Frame
            Positioned.fill(
              child: CustomPaint(
                painter: LootVectorFramePainter(
                  borderColor: theme.borderColor,
                  accentColor: theme.accentColor,
                ),
              ),
            ),

            // 3. Card Content Stack
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Header Row: Tier Badge + Runic Glyph + Odds Preview Trigger
                  Row(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                          border: Border.all(
                            color: theme.accentColor.withValues(alpha: 0.8),
                            width: 0.9,
                          ),
                        ),
                        child: Text(
                          '${theme.tier.tierBadge} · ${theme.tier.runicGlyphs.first}',
                          style: AppTextStyles.micro.copyWith(
                            color: theme.accentColor,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Drop Rates Trigger Button
                      if (onDropRatesTap != null)
                        InkWell(
                          onTap: onDropRatesTap,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: AppSpacing.xs,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const Icon(Icons.percent_rounded, size: 11, color: Colors.white70),
                                const SizedBox(width: AppSpacing.xs),
                                Text(
                                  'Oranlar',
                                  style: AppTextStyles.micro.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Center Stage: 3D Chest Illustration with Floating Breathing Motion
                  Center(
                    child: Loot3DChestIllustration(
                      theme: theme,
                      size: 130,
                      isLocked: isLocked,
                      showHalo: true,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Chest Title & Material Subtitle
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.h3.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Live Status Bars: Lock Countdown Timer & Key Requirements
                  if (unlockTime != null || isLocked || keyRequirement != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.xs,
                        children: <Widget>[
                          if (unlockTime != null || isLocked)
                            LootLockCountdownTimer(
                              unlockTime: unlockTime,
                              isLocked: isLocked,
                              accentColor: theme.accentColor,
                            ),
                          if (keyRequirement != null)
                            LootKeyRequirementBadge(requirement: keyRequirement!),
                        ],
                      ),
                    ),

                  // Dual Action Buttons (1x & 10x)
                  Row(
                    children: <Widget>[
                      // 1x Open Button
                      Expanded(
                        child: LootChestOpenButton(
                          onPressed: onOpen,
                          isLoading: isOpening,
                          isLocked: isLocked,
                          isFree: isFreeSummon,
                          priceLabel: lootCompactNum(box.price),
                          priceIcon: currencyIcon,
                          priceColor: currencyColor,
                          accentColor: theme.accentColor,
                          keySatisfied: keyRequirement?.isSatisfied ?? true,
                          label: '1x Kasa Aç',
                        ),
                      ),
                      if (onOpen10x != null) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        // 10x Discount Open Button
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: (isOpening || isLocked) ? null : onOpen10x,
                            icon: Icon(currencyIcon, size: 14, color: currencyColor),
                            label: Text(
                              '10x (${lootCompactNum(multiPrice)})',
                              style: AppTextStyles.titleBold.copyWith(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: theme.accentColor.withValues(alpha: 0.8),
                                width: 1.4,
                              ),
                              backgroundColor: theme.accentColor.withValues(alpha: 0.14),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                            ),
                          ),
                        ),
                      ],
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
}

class _EternalRunicChainsStaticOverlay extends StatelessWidget {
  const _EternalRunicChainsStaticOverlay({required this.glowColor});

  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomPaint(
        painter: _EternalRunicChainsPainter(
          glowColor: glowColor,
          pulse: 0.5,
        ),
      ),
    );
  }
}

// =============================================================================
// 10. REWARD CARD WITH 3D FLIP, HOLOGRAPHIC SHIMMER & RARITY CHIME
// =============================================================================

/// Floating 3D Reward Card with 3D Flip on Reveal, Holographic Shimmer, and Rarity Chime.
class Loot3DRewardCard extends StatefulWidget {
  const Loot3DRewardCard({
    super.key,
    required this.itemId,
    required this.itemName,
    required this.icon,
    required this.rarity,
    required this.quantity,
    this.tier = LootChestTier.common,
    this.isRevealed = false,
    this.onReveal,
    this.width = 138,
    this.height = 196,
    this.autoFlipDelay,
    this.isJackpot = false,
  });

  final String itemId;
  final String itemName;
  final String icon;
  final String rarity;
  final int quantity;
  final LootChestTier tier;
  final bool isRevealed;
  final VoidCallback? onReveal;
  final double width;
  final double height;
  final Duration? autoFlipDelay;
  final bool isJackpot;

  @override
  State<Loot3DRewardCard> createState() => _Loot3DRewardCardState();
}

class _Loot3DRewardCardState extends State<Loot3DRewardCard>
    with TickerProviderStateMixin {
  late final AnimationController _flipController;
  late final AnimationController _floatController;
  late final AnimationController _shimmerController;
  late final AnimationController _chimeWaveController;

  bool _chimed = false;
  late bool _revealed;

  @override
  void initState() {
    super.initState();
    _revealed = widget.isRevealed;

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
      value: _revealed ? 1.0 : 0.0,
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();

    _chimeWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _flipController.addListener(() {
      if (_flipController.value >= 0.5 && !_chimed) {
        _chimed = true;
        _chimeWaveController.forward(from: 0.0);
        LootRarityChime.trigger(context, widget.tier);
        widget.onReveal?.call();
      }
    });

    if (widget.autoFlipDelay != null && !_revealed) {
      Future<void>.delayed(widget.autoFlipDelay!, () {
        if (mounted && !_revealed) {
          reveal();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant Loot3DRewardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed != oldWidget.isRevealed) {
      if (widget.isRevealed && !_revealed) {
        reveal();
      }
    }
  }

  void reveal() {
    if (_revealed) return;
    setState(() => _revealed = true);
    _flipController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _flipController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    _chimeWaveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = AppColors.forRarity(widget.rarity);
    final Color tierAccent = widget.tier.accentColor;

    return GestureDetector(
      onTap: reveal,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          _flipController,
          _floatController,
          _shimmerController,
          _chimeWaveController,
        ]),
        builder: (BuildContext context, _) {
          final double flipVal = _flipController.value;
          final double angle = flipVal * math.pi;
          final bool isFront = flipVal >= 0.5;

          final double floatY = math.sin(_floatController.value * math.pi) * 3.5;
          final double tiltX = math.cos(_floatController.value * math.pi) * 0.03;

          final Matrix4 transform = Matrix4.identity()
            ..setEntry(3, 2, 0.0022)
            ..translate(0.0, floatY)
            ..rotateX(tiltX)
            ..rotateY(angle);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: <Widget>[
              if (_chimeWaveController.isAnimating)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ChimeWavePainter(
                      progress: _chimeWaveController.value,
                      color: tierAccent,
                    ),
                  ),
                ),
              Transform(
                alignment: Alignment.center,
                transform: transform,
                child: SizedBox(
                  width: widget.width,
                  height: widget.height,
                  child: isFront
                      ? Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(math.pi),
                          child: _buildCardFront(rarityColor, tierAccent),
                        )
                      : _buildCardBack(tierAccent),
                ),
              ),
              if (widget.isJackpot && isFront)
                Positioned(
                  top: -8 + floatY,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[AppColors.goldLight, AppColors.gold],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.6),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      'EN IYI DROP',
                      style: AppTextStyles.micro.copyWith(
                        color: const Color(0xFF1F1202),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCardBack(Color tierAccent) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.bgCardElevated,
            AppColors.bgDeep,
            widget.tier.primaryColor.withValues(alpha: 0.4),
          ],
        ),
        border: Border.all(
          color: widget.tier.borderColor.withValues(alpha: 0.75),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: widget.tier.glowColor,
            blurRadius: 14,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: tierAccent.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Center(
              child: Text(
                widget.tier.runicGlyphs.first,
                style: TextStyle(
                  color: tierAccent.withValues(alpha: 0.85),
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: AppSpacing.md,
            child: Text(
              'ACMAK ICIN DOKUN',
              style: AppTextStyles.micro.copyWith(
                color: Colors.white.withValues(alpha: 0.65),
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardFront(Color rarityColor, Color tierAccent) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            rarityColor.withValues(alpha: 0.35),
            AppColors.bgBase,
            AppColors.bgDeep,
          ],
        ),
        border: Border.all(
          color: rarityColor.withValues(alpha: 0.85),
          width: 1.6,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: rarityColor.withValues(alpha: 0.40),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _HolographicShimmerPainter(
                  progress: _shimmerController.value,
                  tierColor: tierAccent,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: rarityColor.withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          lootDropCategoryLabel(widget.itemId),
                          style: AppTextStyles.micro.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        widget.rarity.toUpperCase(),
                        style: AppTextStyles.micro.copyWith(
                          color: rarityColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Center(
                      child: ItemIconView(
                        iconValue: widget.icon,
                        itemId: widget.itemId,
                        size: 64,
                        expand: false,
                        fallback: '◻',
                      ),
                    ),
                  ),
                  Text(
                    widget.itemName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                        ),
                        child: Text(
                          'x${widget.quantity}',
                          style: AppTextStyles.label.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: rarityColor,
                          shape: BoxShape.circle,
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
}

class _ChimeWavePainter extends CustomPainter {
  const _ChimeWavePainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = (size.width * 0.45) + (progress * 48);
    final double opacity = (1.0 - progress).clamp(0.0, 1.0);

    final Paint paint = Paint()
      ..color = color.withValues(alpha: opacity * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      radius,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ChimeWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

// =============================================================================
// 11. MULTI-OPEN 10X SUMMARY GRID & DIALOG
// =============================================================================

/// 2027 Aion 2 Multi-Open 10x Summary Grid with Instant Share & Claim All.
class LootMultiOpenSummaryGrid extends StatefulWidget {
  const LootMultiOpenSummaryGrid({
    super.key,
    required this.rewards,
    required this.theme,
    required this.onClaimAll,
    this.onShare,
    this.boxName = 'Sandık',
  });

  final List<LootMultiOpenReward> rewards;
  final LootChestTheme theme;
  final VoidCallback onClaimAll;
  final VoidCallback? onShare;
  final String boxName;

  @override
  State<LootMultiOpenSummaryGrid> createState() =>
      _LootMultiOpenSummaryGridState();
}

class _LootMultiOpenSummaryGridState extends State<LootMultiOpenSummaryGrid> {
  bool _revealedAll = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _revealedAll = true);
    });
  }

  LootMultiOpenReward? get _bestReward {
    if (widget.rewards.isEmpty) return null;
    const Map<String, int> ranks = <String, int>{
      'eternal': 5,
      'ebedi': 5,
      'archon': 5,
      'mythic': 4,
      'fabled': 4,
      'efsanevi': 4,
      'legendary': 4,
      'heroic': 3,
      'epic': 3,
      'rare': 2,
      'nadir': 2,
      'uncommon': 1,
      'common': 0,
    };

    LootMultiOpenReward best = widget.rewards.first;
    int bestRank = ranks[best.rarity.toLowerCase()] ?? 0;
    for (final LootMultiOpenReward item in widget.rewards) {
      final int r = ranks[item.rarity.toLowerCase()] ?? 0;
      if (r > bestRank) {
        bestRank = r;
        best = item;
      }
    }
    return best;
  }

  void _handleShare(BuildContext context) {
    LootRarityChime.trigger(context, widget.theme.tier);
    final String best = _bestReward?.itemName ?? 'Nadir Eşyalar';
    final String shareText =
        '[GKK] 10x ${widget.boxName} açılışı tamamlandı! En iyi drop: $best!';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Paylaşıldı: $shareText',
          style: AppTextStyles.bodyBold.copyWith(color: Colors.white),
        ),
        backgroundColor: widget.theme.accentColor,
        duration: const Duration(seconds: 2),
      ),
    );

    widget.onShare?.call();
  }

  @override
  Widget build(BuildContext context) {
    final LootMultiOpenReward? best = _bestReward;

    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.md, AppSpacing.base, AppSpacing.base),
      decoration: BoxDecoration(
        color: AppColors.bgDeep.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXxl),
        border: Border.all(
          color: widget.theme.borderColor.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: widget.theme.glowColor,
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Header Bar
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.theme.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  border: Border.all(color: widget.theme.accentColor, width: 1),
                ),
                child: Text(
                  widget.theme.tier.tierBadge,
                  style: AppTextStyles.micro.copyWith(
                    color: widget.theme.accentColor,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '10x ${widget.boxName.toUpperCase()}',
                      style: AppTextStyles.h3.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      widget.theme.materialDescription,
                      style: AppTextStyles.micro.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 10x Card Grid (5 columns x 2 rows)
          Flexible(
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.rewards.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 0.68,
                crossAxisSpacing: 6,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (BuildContext context, int index) {
                final LootMultiOpenReward item = widget.rewards[index];
                final bool isJackpot = best == item;

                return Loot3DRewardCard(
                  itemId: item.itemId,
                  itemName: item.itemName,
                  icon: item.icon,
                  rarity: item.rarity,
                  quantity: item.quantity,
                  tier: widget.theme.tier,
                  isRevealed: _revealedAll,
                  autoFlipDelay: Duration(milliseconds: index * 60),
                  isJackpot: isJackpot,
                  width: 60,
                  height: 94,
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // Action Buttons: Instant Share + Claim All
          Row(
            children: <Widget>[
              // Instant Share Button
              OutlinedButton.icon(
                onPressed: () => _handleShare(context),
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('PAYLAŞ'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Claim All Button
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    LootRarityChime.trigger(context, widget.theme.tier);
                    widget.onClaimAll();
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text(
                    'TÜMÜNÜ AL (10x)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: widget.theme.accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    elevation: 6,
                    shadowColor: widget.theme.accentColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Modal Presentation Helper for 10x Multi-Open Summary.
abstract final class LootMultiOpenDialog {
  static Future<void> show({
    required BuildContext context,
    required List<LootMultiOpenReward> rewards,
    required LootChestTheme theme,
    required VoidCallback onClaimAll,
    VoidCallback? onShare,
    String boxName = 'Sandık',
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xl),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: LootMultiOpenSummaryGrid(
              rewards: rewards,
              theme: theme,
              boxName: boxName,
              onClaimAll: () {
                Navigator.of(dialogContext).pop();
                onClaimAll();
              },
              onShare: onShare,
            ),
          ),
        );
      },
    );
  }
}

// =============================================================================
// 12. MODERNIZED 2027 AION 2 LOOT CHEST BANNER
// =============================================================================

/// Modernized 2027 Aion 2 Loot Chest Banner with floating 3D chest & ambient halo.
class LootChestBanner extends StatefulWidget {
  const LootChestBanner({
    super.key,
    required this.theme,
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.priceIcon,
    required this.priceColor,
    required this.footer,
    this.height,
    this.isLocked = false,
    this.unlockTime,
    this.keyRequirement,
    this.onDropRatesTap,
  });

  final LootChestTheme theme;
  final String title;
  final String subtitle;
  final String priceLabel;
  final IconData priceIcon;
  final Color priceColor;
  final Widget footer;
  final double? height;
  final bool isLocked;
  final DateTime? unlockTime;
  final LootKeyRequirement? keyRequirement;
  final VoidCallback? onDropRatesTap;

  @override
  State<LootChestBanner> createState() => _LootChestBannerState();
}

class _LootChestBannerState extends State<LootChestBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double textScale = MediaQuery.textScalerOf(context).scale(1);
    final LootChestTheme theme = widget.theme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _LootBannerLayout layout = _LootBannerLayout(
          bannerWidth: constraints.maxWidth,
          textScale: textScale,
          heightOverride: widget.height,
        );

        return SizedBox(
          width: double.infinity,
          height: layout.bannerHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // 1. Background Radial Card with Specular Sheen
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    gradient: RadialGradient(
                      center: const Alignment(0.6, 0.0),
                      radius: 1.5,
                      colors: <Color>[theme.radialCenter, theme.radialEdge],
                    ),
                    border: Border.all(color: theme.borderColor, width: 1.4),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: theme.tier.glowColor,
                        blurRadius: 18,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
                    child: Stack(
                      children: <Widget>[
                        CustomPaint(painter: LootChestGridPainter()),

                        // Eternal Burning Runic Chains Overlay
                        if (theme.isEternal)
                          AnimatedBuilder(
                            animation: _animController,
                            builder: (BuildContext context, _) {
                              return CustomPaint(
                                size: Size.infinite,
                                painter: _EternalRunicChainsPainter(
                                  glowColor: theme.tier.chainColor,
                                  pulse: _animController.value,
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. Ambient Rarity Halo Behind Chest
              Positioned(
                right: layout.imageRight - 20,
                top: layout.imageTopBottom - 20,
                width: layout.imageWidth + 40,
                height: layout.imageWidth + 40,
                child: LootChestRarityHalo(
                  tier: theme.tier,
                  size: layout.imageWidth + 40,
                  customColor: theme.accentColor,
                ),
              ),

              // 3. Floating 3D Chest Art Illustration
              Positioned(
                right: layout.imageRight,
                top: layout.imageTopBottom,
                bottom: layout.imageTopBottom,
                width: layout.imageWidth,
                child: AnimatedBuilder(
                  animation: _animController,
                  builder: (BuildContext context, _) {
                    final double floatY = math.sin(_animController.value * math.pi) * 3.5;
                    return Transform.translate(
                      offset: Offset(0, floatY),
                      child: Image.asset(
                        theme.assetPath,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => AionChestIllustration(
                          tier: theme.tier,
                          size: layout.imageWidth,
                          showGlow: true,
                        ),
                      ),
                    );
                  },
                ),
              ),

              // 4. Content Details Column
              Positioned(
                left: layout.horizontalInset,
                top: layout.verticalInset,
                bottom: layout.verticalInset,
                right: layout.contentRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Tier Badge Pill & Lock/Key Status Tags
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                            border: Border.all(
                              color: theme.accentColor.withValues(alpha: 0.7),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            '${theme.tier.tierBadge} · ${theme.tier.runicGlyphs.first}',
                            style: AppTextStyles.micro.copyWith(
                              color: theme.accentColor,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (widget.unlockTime != null || widget.isLocked)
                          LootLockCountdownTimer(
                            unlockTime: widget.unlockTime,
                            isLocked: widget.isLocked,
                            accentColor: theme.accentColor,
                            compact: true,
                          ),
                        if (widget.keyRequirement != null)
                          LootKeyRequirementBadge(
                            requirement: widget.keyRequirement!,
                            compact: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.title,
                        style: GoogleFonts.urbanist(
                          textStyle: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: layout.titleSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: layout.tight ? 2 : 4),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          widget.subtitle,
                          maxLines: layout.tight ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: layout.subtitleSize,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: layout.tight ? 6 : AppSpacing.sm),
                    widget.footer,
                  ],
                ),
              ),

              // 5. Price Badge
              Positioned(
                top: layout.priceInset,
                right: layout.priceInset,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.tight ? AppSpacing.sm : 10,
                    vertical: layout.tight ? 5 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: widget.priceColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        widget.priceIcon,
                        size: layout.tight ? 12 : 14,
                        color: widget.priceColor,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        widget.priceLabel,
                        style: AppTextStyles.label.copyWith(
                          color: widget.priceColor,
                          fontWeight: FontWeight.w800,
                          fontSize: layout.tight ? 11 : 12,
                        ),
                      ),
                    ],
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

// =============================================================================
// 13. LOOT DROP PREVIEW DIALOG
// =============================================================================

/// Modernized Loot Drop Preview Dialog with Glassmorphism.
class LootDropPreviewDialog extends StatelessWidget {
  const LootDropPreviewDialog({super.key, required this.drop});

  final LootDropPreviewData drop;

  static Future<void> show(BuildContext context, LootDropPreviewData drop) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (BuildContext dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.base, vertical: AppSpacing.xxl),
          backgroundColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: LootDropPreviewDialog(drop: drop),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Ink(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            color: isPrimary ? AppColors.gold : AppColors.bgCard,
            border: isPrimary
                ? null
                : Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: isPrimary
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: AppTextStyles.dialogButton.copyWith(
                color: isPrimary ? Colors.black : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Color rarityColor = drop.rarityColor;
    final List<(String, String)> stats = <(String, String)>[
      ('DROP ORANI', '%${drop.dropRate.toStringAsFixed(2)}'),
      ('MİKTAR', 'x${drop.minQuantity}-${drop.maxQuantity}'),
      ('NADİRLİK', drop.rarity.toUpperCase()),
    ];

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: rarityColor.withValues(alpha: 0.65),
            width: 1.5,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: rarityColor.withValues(alpha: 0.35),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: Center(
                      child: ItemIconView(
                        iconValue: drop.icon,
                        itemId: drop.itemId,
                        size: 78,
                        expand: true,
                        fallback: '◻',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Builder(
                          builder: (BuildContext ctx) {
                            return _buildActionButton(
                              label: ctx.l10n.drop_ni_zleme,
                              onPressed: () => Navigator.of(ctx).pop(),
                              isPrimary: true,
                            );
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildActionButton(
                          label: context.l10n.kapat_2,
                          onPressed: () => Navigator.of(context).pop(),
                          isPrimary: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'EŞYA ADI',
                style: AppTextStyles.micro.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                drop.itemName.toUpperCase(),
                style: AppTextStyles.h1.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${drop.rarity.toUpperCase()} · ${lootDropCategoryLabel(drop.itemId)}',
                style: AppTextStyles.label.copyWith(
                  color: rarityColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Bu eşya kasa açılışında drop havuzundan çıkabilir.',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: 6,
                children: stats.map((stat) {
                  return Text(
                    '${stat.$1}: ${stat.$2}',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LootDropPreviewData {
  const LootDropPreviewData({
    required this.itemId,
    required this.itemName,
    required this.icon,
    required this.rarity,
    required this.dropRate,
    required this.minQuantity,
    required this.maxQuantity,
    required this.rarityColor,
  });

  final String itemId;
  final String itemName;
  final String icon;
  final String rarity;
  final double dropRate;
  final int minQuantity;
  final int maxQuantity;
  final Color rarityColor;
}
