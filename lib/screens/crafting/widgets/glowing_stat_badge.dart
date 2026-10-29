import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../inventory/widgets/aion_rarity_glow.dart';

/// Layout variant for GlowingStatBadge.
enum GlowingStatBadgeVariant {
  pill,
  card,
  compact,
  metallic,
}

/// Reusable 2027 Aion 2 Mobile glass & metallic glowing stat badge.
///
/// Used for:
/// - Item Rarity (Common, Rare, Epic, Mythic, Archon)
/// - Item Tier / Level / Enhancement
/// - Crafting Success Chance (e.g. 85% with mini radial gauge)
/// - Custom combat/economic statistics
///
/// Features:
/// - Frosted glass translucent dark background with metallic border.
/// - Ambient rarity/status glow with optional animated pulse.
/// - Tactile haptic feedback on tap.
/// - Zero overflow on compact 390x844 mobile screens.
class GlowingStatBadge extends StatefulWidget {
  const GlowingStatBadge({
    super.key,
    required this.label,
    this.value,
    this.icon,
    this.tier,
    this.badgeColor,
    this.secondaryColor,
    this.variant = GlowingStatBadgeVariant.pill,
    this.isGlowing = true,
    this.isPulsing = false,
    this.progress,
    this.onTap,
    this.padding,
    this.borderRadius,
    this.fontSize,
  });

  /// The label displayed on the badge (e.g. 'BAŞARI', 'DESTANSI', 'TIER IV').
  final String label;

  /// Optional value text (e.g. '85%', '+12', '100%').
  final String? value;

  /// Optional icon displayed before the label/value.
  final dynamic icon;

  /// Optional Aion rarity tier to automatically bind colors and glow.
  final AionRarityTier? tier;

  /// Custom primary accent / glow color (overrides tier).
  final Color? badgeColor;

  /// Custom secondary color (overrides tier).
  final Color? secondaryColor;

  /// Visual styling variant.
  final GlowingStatBadgeVariant variant;

  /// Whether to emit an ambient colored glow aura.
  final bool isGlowing;

  /// Whether the glow aura pulses gently.
  final bool isPulsing;

  /// Optional progress ratio (0.0 to 1.0), renders a mini progress circle or bar.
  final double? progress;

  /// Optional tap callback.
  final VoidCallback? onTap;

  /// Optional custom padding.
  final EdgeInsetsGeometry? padding;

  /// Optional custom border radius.
  final BorderRadiusGeometry? borderRadius;

  /// Optional base font size override.
  final double? fontSize;

  @override
  State<GlowingStatBadge> createState() => _GlowingStatBadgeState();
}

class _GlowingStatBadgeState extends State<GlowingStatBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.isPulsing) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant GlowingStatBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing != oldWidget.isPulsing) {
      if (widget.isPulsing) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = widget.badgeColor ??
        (widget.tier != null ? widget.tier!.primaryColor : AppColors.liquidGold);
    final Color secondaryColor = widget.secondaryColor ??
        (widget.tier != null ? widget.tier!.secondaryColor : AppColors.goldLight);

    final double effectiveFontSize = widget.fontSize ??
        (widget.variant == GlowingStatBadgeVariant.compact ? 10.5 : 11.5);

    final BorderRadius effectiveRadius = widget.borderRadius is BorderRadius
        ? widget.borderRadius as BorderRadius
        : switch (widget.variant) {
            GlowingStatBadgeVariant.pill => BorderRadius.circular(16.0),
            GlowingStatBadgeVariant.compact => BorderRadius.circular(8.0),
            GlowingStatBadgeVariant.card => BorderRadius.circular(10.0),
            GlowingStatBadgeVariant.metallic => BorderRadius.circular(12.0),
          };

    final EdgeInsetsGeometry effectivePadding = widget.padding ??
        switch (widget.variant) {
          GlowingStatBadgeVariant.pill => const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.5),
          GlowingStatBadgeVariant.compact => const EdgeInsets.symmetric(horizontal: 6.0, vertical: 3.0),
          GlowingStatBadgeVariant.card => const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
          GlowingStatBadgeVariant.metallic => const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        };

    Widget badgeContent = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // Optional Progress Gauge or Icon
        if (widget.progress != null) ...<Widget>[
          _buildMiniGauge(primaryColor, (widget.progress!).clamp(0.0, 1.0)),
          const SizedBox(width: 6),
        ] else if (widget.icon != null) ...<Widget>[
          _buildIcon(primaryColor),
          const SizedBox(width: 5),
        ],

        // Label
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: effectiveFontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: primaryColor,
            ),
          ),
        ),

        // Optional Value
        if (widget.value != null && widget.value!.isNotEmpty) ...<Widget>[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.35),
                width: 0.6,
              ),
            ),
            child: Text(
              widget.value!,
              maxLines: 1,
              style: TextStyle(
                fontSize: effectiveFontSize * 0.92,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );

    // Build decoration based on variant and glow
    if (!widget.isPulsing) {
      return _buildContainer(
        content: badgeContent,
        primary: primaryColor,
        secondary: secondaryColor,
        radius: effectiveRadius,
        padding: effectivePadding,
        glowFactor: 1.0,
      );
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        return _buildContainer(
          content: badgeContent,
          primary: primaryColor,
          secondary: secondaryColor,
          radius: effectiveRadius,
          padding: effectivePadding,
          glowFactor: _pulseAnimation.value,
        );
      },
    );
  }

  Widget _buildContainer({
    required Widget content,
    required Color primary,
    required Color secondary,
    required BorderRadius radius,
    required EdgeInsetsGeometry padding,
    required double glowFactor,
  }) {
    final bool hasGlow = widget.isGlowing;

    final BoxDecoration decoration = BoxDecoration(
      color: AppColors.carbonVoid.withValues(alpha: 0.85),
      borderRadius: radius,
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          primary.withValues(alpha: 0.16 * glowFactor),
          AppColors.carbonVoid.withValues(alpha: 0.90),
          secondary.withValues(alpha: 0.08 * glowFactor),
        ],
      ),
      border: Border.all(
        color: primary.withValues(
          alpha: widget.variant == GlowingStatBadgeVariant.metallic
              ? (0.85 * glowFactor).clamp(0.2, 1.0)
              : (0.45 * glowFactor).clamp(0.15, 0.9),
        ),
        width: widget.variant == GlowingStatBadgeVariant.metallic ? 1.2 : 0.8,
      ),
      boxShadow: hasGlow
          ? <BoxShadow>[
              BoxShadow(
                color: primary.withValues(
                  alpha: (0.24 * glowFactor).clamp(0.0, 0.7),
                ),
                blurRadius: 8.0 * glowFactor,
                spreadRadius: 0.5 * glowFactor,
              ),
            ]
          : null,
    );

    Widget container = Container(
      padding: padding,
      decoration: decoration,
      child: content,
    );

    if (widget.onTap != null) {
      container = InkWell(
        onTap: () {
          AionHaptics.slotSelect();
          widget.onTap?.call();
        },
        borderRadius: radius,
        child: container,
      );
    }

    return container;
  }

  Widget _buildIcon(Color color) {
    if (widget.icon is IconData) {
      return Icon(
        widget.icon as IconData,
        size: 13.0,
        color: color,
      );
    } else if (widget.icon is Widget) {
      return widget.icon as Widget;
    }
    return const SizedBox.shrink();
  }

  Widget _buildMiniGauge(Color color, double progress) {
    return SizedBox(
      width: 14,
      height: 14,
      child: CustomPaint(
        painter: _MiniCircularGaugePainter(
          progress: progress,
          color: color,
          trackColor: Colors.white12,
        ),
      ),
    );
  }
}

class _MiniCircularGaugePainter extends CustomPainter {
  const _MiniCircularGaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width / 2) - 1.2;

    final Paint trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = trackColor;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0.0) {
      final Paint progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..color = color;

      final double sweepAngle = 2 * math.pi * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniCircularGaugePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.trackColor != trackColor;
  }
}
