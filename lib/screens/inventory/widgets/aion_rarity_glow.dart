import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/economy_haptics.dart';
import '../../../models/item_model.dart';
import '../../../theme/app_colors.dart';

/// Aion 2 Rarity Tiers reflecting AAA modern high-fantasy aesthetics.
enum AionRarityTier {
  common,
  rare,
  epic,
  mythic,
  archon;

  static AionRarityTier fromRarity(Rarity rarity, {int enhancementLevel = 0, String? itemId}) {
    // Archon tier for highest enhancement or explicit archon items
    if (enhancementLevel >= 9 || (itemId != null && itemId.toLowerCase().contains('archon'))) {
      return AionRarityTier.archon;
    }
    return switch (rarity) {
      Rarity.common || Rarity.uncommon => AionRarityTier.common,
      Rarity.rare => AionRarityTier.rare,
      Rarity.epic => AionRarityTier.epic,
      Rarity.legendary || Rarity.mythic => AionRarityTier.mythic,
    };
  }

  static AionRarityTier fromString(String rarity, {int enhancementLevel = 0}) {
    final lower = rarity.toLowerCase().trim();
    if (enhancementLevel >= 9 || lower == 'archon' || lower.contains('archon')) {
      return AionRarityTier.archon;
    }
    return switch (lower) {
      'common' || 'uncommon' || 'siradan' || 'yaygin olmayan' => AionRarityTier.common,
      'rare' || 'nadir' => AionRarityTier.rare,
      'epic' || 'destansi' => AionRarityTier.epic,
      'mythic' || 'legendary' || 'mitik' || 'efsanevi' => AionRarityTier.mythic,
      _ => AionRarityTier.common,
    };
  }

  Color get primaryColor => switch (this) {
        AionRarityTier.common => const Color(0xFF94A3B8), // Mithril Slate
        AionRarityTier.rare => const Color(0xFF38BDF8),   // Celestial Azure
        AionRarityTier.epic => const Color(0xFFA855F7),   // Royal Arcane Violet
        AionRarityTier.mythic => const Color(0xFFF43F5E), // Dragonfire Crimson
        AionRarityTier.archon => const Color(0xFFFFB800), // Divine Prismatic Gold
      };

  Color get secondaryColor => switch (this) {
        AionRarityTier.common => const Color(0xFF475569),
        AionRarityTier.rare => const Color(0xFF0284C7),
        AionRarityTier.epic => const Color(0xFF7E22CE),
        AionRarityTier.mythic => const Color(0xFFBE123C),
        AionRarityTier.archon => const Color(0xFF06D0D8), // Astral Cyan duality
      };

  Color get glowColor => primaryColor.withValues(alpha: switch (this) {
        AionRarityTier.common => 0.18,
        AionRarityTier.rare => 0.35,
        AionRarityTier.epic => 0.45,
        AionRarityTier.mythic => 0.55,
        AionRarityTier.archon => 0.70,
      });

  double get glowBlurRadius => switch (this) {
        AionRarityTier.common => 4.0,
        AionRarityTier.rare => 8.0,
        AionRarityTier.epic => 12.0,
        AionRarityTier.mythic => 16.0,
        AionRarityTier.archon => 20.0,
      };

  String get displayName => switch (this) {
        AionRarityTier.common => 'SIRADAN',
        AionRarityTier.rare => 'NADİR',
        AionRarityTier.epic => 'DESTANSI',
        AionRarityTier.mythic => 'MİTİK',
        AionRarityTier.archon => 'ARKON',
      };

  bool get hasSparkles => this != AionRarityTier.common;
}

/// Mobile tactile HapticFeedback helper with defensive platform handling.
abstract final class AionHaptics {
  static Future<void> slotSelect() => EconomyHaptics.slotSelect();
  static Future<void> dragStart() => EconomyHaptics.itemDragStart();
  static Future<void> slotDrop() => EconomyHaptics.itemDrop();
  static Future<void> equipSuccess() => EconomyHaptics.craftSuccess();
  static Future<void> craftSuccess() => EconomyHaptics.craftSuccess();
  static Future<void> tabSwitch() => EconomyHaptics.tabSwitch();
  static Future<void> error() => EconomyHaptics.error();
  static Future<void> buttonTap() => EconomyHaptics.buttonTap();
}

/// Aion 2 glowing rarity border with optional corner runes and specular glint.
class AionRarityGlowBorder extends StatelessWidget {
  const AionRarityGlowBorder({
    super.key,
    required this.child,
    required this.tier,
    this.borderRadius = 12.0,
    this.borderWidth = 1.2,
    this.isSelected = false,
    this.isHighlighted = false,
    this.hasActiveGlow = true,
    this.showCornerRunes = true,
  });

  final Widget child;
  final AionRarityTier tier;
  final double borderRadius;
  final double borderWidth;
  final bool isSelected;
  final bool isHighlighted;
  final bool hasActiveGlow;
  final bool showCornerRunes;

  @override
  Widget build(BuildContext context) {
    final Color primary = isSelected
        ? Theme.of(context).colorScheme.primary
        : isHighlighted
            ? AppColors.liquidGold
            : tier.primaryColor;
    final Color secondary = isSelected
        ? primary
        : isHighlighted
            ? const Color(0xFFFDE68A)
            : tier.secondaryColor;

    final double effectiveWidth = (isSelected || isHighlighted)
        ? borderWidth * 1.8
        : (tier == AionRarityTier.archon || tier == AionRarityTier.mythic ? borderWidth * 1.4 : borderWidth);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: hasActiveGlow
            ? <BoxShadow>[
                BoxShadow(
                  color: (isSelected || isHighlighted
                          ? primary
                          : tier.glowColor)
                      .withValues(alpha: isSelected ? 0.45 : 0.25),
                  blurRadius: isSelected ? 12 : tier.glowBlurRadius,
                  spreadRadius: isSelected ? 1 : 0,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: CustomPaint(
          foregroundPainter: _AionBorderPainter(
            primaryColor: primary,
            secondaryColor: secondary,
            borderWidth: effectiveWidth,
            borderRadius: borderRadius,
            tier: tier,
            showCornerRunes: showCornerRunes && (tier.index >= AionRarityTier.epic.index || isSelected),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _AionBorderPainter extends CustomPainter {
  const _AionBorderPainter({
    required this.primaryColor,
    required this.secondaryColor,
    required this.borderWidth,
    required this.borderRadius,
    required this.tier,
    required this.showCornerRunes,
  });

  final Color primaryColor;
  final Color secondaryColor;
  final double borderWidth;
  final double borderRadius;
  final AionRarityTier tier;
  final bool showCornerRunes;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Rect rect = Offset.zero & size;
    final RRect rrect = RRect.fromRectAndRadius(
      rect.deflate(borderWidth / 2),
      Radius.circular(math.max(0, borderRadius - borderWidth / 2)),
    );

    // Gradient border stroke
    final Paint borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          primaryColor.withValues(alpha: 0.95),
          secondaryColor.withValues(alpha: 0.75),
          primaryColor.withValues(alpha: 0.85),
        ],
        stops: const <double>[0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, borderPaint);

    // Specular top highlight (Aion 2 polished metal sheen)
    final Paint specularPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.min(1.0, borderWidth)
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withValues(alpha: 0.40),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.35));

    final Path topHighlight = Path()
      ..moveTo(borderRadius, borderWidth / 2)
      ..lineTo(size.width - borderRadius, borderWidth / 2);
    canvas.drawPath(topHighlight, specularPaint);

    // Corner Runes / Socket Brackets for Epic, Mythic, Archon
    if (showCornerRunes && size.width >= 40 && size.height >= 40) {
      final Paint runePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, borderWidth)
        ..color = primaryColor.withValues(alpha: 0.95);

      const double notch = 5.0;
      // Top Left
      canvas.drawLine(const Offset(3, 3 + notch), const Offset(3, 3), runePaint);
      canvas.drawLine(const Offset(3, 3), const Offset(3 + notch, 3), runePaint);

      // Top Right
      canvas.drawLine(Offset(size.width - 3 - notch, 3), Offset(size.width - 3, 3), runePaint);
      canvas.drawLine(Offset(size.width - 3, 3), Offset(size.width - 3, 3 + notch), runePaint);

      // Bottom Left
      canvas.drawLine(Offset(3, size.height - 3 - notch), Offset(3, size.height - 3), runePaint);
      canvas.drawLine(Offset(3, size.height - 3), Offset(3 + notch, size.height - 3), runePaint);

      // Bottom Right
      canvas.drawLine(Offset(size.width - 3 - notch, size.height - 3), Offset(size.width - 3, size.height - 3), runePaint);
      canvas.drawLine(Offset(size.width - 3, size.height - 3 - notch), Offset(size.width - 3, size.height - 3), runePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AionBorderPainter old) {
    return old.primaryColor != primaryColor ||
        old.secondaryColor != secondaryColor ||
        old.borderWidth != borderWidth ||
        old.borderRadius != borderRadius ||
        old.tier != tier ||
        old.showCornerRunes != showCornerRunes;
  }
}

/// Particle model for Enchanting particle sparkles.
class _SparkleParticle {
  _SparkleParticle({
    required this.xRatio,
    required this.yRatio,
    required this.size,
    required this.speed,
    required this.phase,
    required this.isDiamond,
  });

  final double xRatio;
  final double yRatio;
  final double size;
  final double speed;
  final double phase;
  final bool isDiamond;
}

/// High-performance, zero-GC enchanting particle canvas.
class EnchantingSparklesOverlay extends StatefulWidget {
  const EnchantingSparklesOverlay({
    super.key,
    required this.tier,
    this.particleCount = 8,
    this.speed = 1.0,
    this.child,
  });

  final AionRarityTier tier;
  final int particleCount;
  final double speed;
  final Widget? child;

  @override
  State<EnchantingSparklesOverlay> createState() => _EnchantingSparklesOverlayState();
}

class _EnchantingSparklesOverlayState extends State<EnchantingSparklesOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_SparkleParticle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (2400 / widget.speed).round()),
    )..repeat();

    // Deterministic particle initialization (avoid GC allocations during paint)
    final rand = math.Random(widget.tier.index * 77 + widget.particleCount);
    _particles = List<_SparkleParticle>.generate(widget.particleCount, (i) {
      return _SparkleParticle(
        xRatio: rand.nextDouble() * 0.8 + 0.1,
        yRatio: rand.nextDouble() * 0.8 + 0.1,
        size: rand.nextDouble() * 3.5 + 2.0,
        speed: rand.nextDouble() * 0.6 + 0.7,
        phase: rand.nextDouble() * math.pi * 2,
        isDiamond: i % 2 == 0,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.tier.hasSparkles) {
      return widget.child ?? const SizedBox.shrink();
    }

    final Widget canvas = RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _EnchantingSparklesPainter(
              tier: widget.tier,
              progress: _controller.value,
              particles: _particles,
            ),
          );
        },
      ),
    );

    if (widget.child == null) {
      return canvas;
    }

    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child!,
        Positioned.fill(child: IgnorePointer(child: canvas)),
      ],
    );
  }
}

class _EnchantingSparklesPainter extends CustomPainter {
  _EnchantingSparklesPainter({
    required this.tier,
    required this.progress,
    required this.particles,
  })  : _fillPaint = Paint()..style = PaintingStyle.fill,
        _glowPaint = Paint()..style = PaintingStyle.fill;

  final AionRarityTier tier;
  final double progress;
  final List<_SparkleParticle> particles;

  final Paint _fillPaint;
  final Paint _glowPaint;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final Color color = tier.primaryColor;
    final Color glowColor = tier.secondaryColor;

    for (final p in particles) {
      final double t = (progress * p.speed + p.phase / (2 * math.pi)) % 1.0;
      final double opacity = math.sin(t * math.pi).clamp(0.0, 1.0);
      if (opacity <= 0.05) continue;

      // Gentle vertical floating motion
      final double x = p.xRatio * size.width;
      final double y = ((p.yRatio - t * 0.25) % 1.0) * size.height;

      _glowPaint.color = glowColor.withValues(alpha: opacity * 0.35);
      _fillPaint.color = color.withValues(alpha: opacity * 0.85);

      final double radius = p.size;

      // Draw soft glow aura behind sparkle
      canvas.drawCircle(Offset(x, y), radius * 1.5, _glowPaint);

      if (p.isDiamond) {
        // Draw 4-point star / diamond
        final Path star = Path()
          ..moveTo(x, y - radius)
          ..lineTo(x + radius * 0.4, y)
          ..lineTo(x, y + radius)
          ..lineTo(x - radius * 0.4, y)
          ..close()
          ..moveTo(x - radius, y)
          ..lineTo(x, y + radius * 0.4)
          ..lineTo(x + radius, y)
          ..lineTo(x, y - radius * 0.4)
          ..close();
        canvas.drawPath(star, _fillPaint);
      } else {
        // Draw glint circle with core
        canvas.drawCircle(Offset(x, y), radius * 0.7, _fillPaint);
        _fillPaint.color = Colors.white.withValues(alpha: opacity * 0.9);
        canvas.drawCircle(Offset(x, y), radius * 0.35, _fillPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EnchantingSparklesPainter old) {
    return old.progress != progress || old.tier != tier;
  }
}
