import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// Decorative wing flourishes flanking the title and runes.
enum RunicWingsStyle {
  none,
  metallic,
  flourish,
  gem,
}

/// Reusable 2027 Aion 2 Mobile ornate runic header banner.
///
/// Features:
/// - Ornate fantasy title banner with glowing runic accents.
/// - Left & right decorative metallic wings or gem flourishes.
/// - Optional animated pulsing rune glow for AAA alive presence.
/// - Full 390x844 mobile responsiveness: flexible layout, auto-truncating
///   overflow handling, zero horizontal render overflow.
/// - Optional leading and trailing action slots.
class RunicHeader extends StatefulWidget {
  const RunicHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.rune = 'ᛟ',
    this.runeColor,
    this.glowColor,
    this.glowIntensity = 0.7,
    this.isAnimated = true,
    this.wingsStyle = RunicWingsStyle.metallic,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
    this.titleStyle,
    this.subtitleStyle,
    this.textAlign = TextAlign.center,
  });

  /// The primary title text or widget.
  final dynamic title;

  /// Optional subtitle string or widget.
  final dynamic subtitle;

  /// Central or flanking runic character or symbol (e.g. 'ᛟ', 'ᚱ', '✦').
  final String rune;

  /// Base color of the rune accent. Defaults to [AppColors.liquidGold].
  final Color? runeColor;

  /// Ambient glow halo color. Defaults to [runeColor] with alpha.
  final Color? glowColor;

  /// Intensity of the rune glow (0.0 to 1.0).
  final double glowIntensity;

  /// Whether the rune glow breathes with a subtle pulse animation.
  final bool isAnimated;

  /// Decorative wing flourish style flanking the runes.
  final RunicWingsStyle wingsStyle;

  /// Optional leading widget (e.g. back icon, emblem).
  final Widget? leading;

  /// Optional trailing widget (e.g. close button, stat badge).
  final Widget? trailing;

  /// Outer padding for the header row.
  final EdgeInsetsGeometry padding;

  /// Optional override for the title text style.
  final TextStyle? titleStyle;

  /// Optional override for the subtitle text style.
  final TextStyle? subtitleStyle;

  /// Alignment of the title & subtitle text.
  final TextAlign textAlign;

  @override
  State<RunicHeader> createState() => _RunicHeaderState();
}

class _RunicHeaderState extends State<RunicHeader> with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _glowAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.isAnimated) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant RunicHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimated != oldWidget.isAnimated) {
      if (widget.isAnimated) {
        _glowController.repeat(reverse: true);
      } else {
        _glowController.stop();
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryRune = widget.runeColor ?? AppColors.liquidGold;
    final Color effectiveGlow = widget.glowColor ?? primaryRune;

    return Padding(
      padding: widget.padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (widget.leading != null) ...<Widget>[
            widget.leading!,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: widget.textAlign == TextAlign.left
                  ? CrossAxisAlignment.start
                  : widget.textAlign == TextAlign.right
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.center,
              children: <Widget>[
                // Runic Ornament Row above or beside title
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: widget.textAlign == TextAlign.left
                      ? MainAxisAlignment.start
                      : widget.textAlign == TextAlign.right
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.center,
                  children: <Widget>[
                    if (widget.wingsStyle != RunicWingsStyle.none)
                      _buildWing(isLeft: true, color: primaryRune),
                    if (widget.rune.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 6),
                      _buildAnimatedRune(primaryRune, effectiveGlow),
                      const SizedBox(width: 6),
                    ],
                    if (widget.wingsStyle != RunicWingsStyle.none)
                      _buildWing(isLeft: false, color: primaryRune),
                  ],
                ),
                const SizedBox(height: 4),

                // Title Widget
                if (widget.title is Widget)
                  widget.title as Widget
                else if (widget.title is String)
                  Text(
                    widget.title as String,
                    textAlign: widget.textAlign,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: widget.titleStyle ??
                        TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.textPrimary,
                          shadows: <Shadow>[
                            Shadow(
                              color: primaryRune.withValues(alpha: 0.35),
                              blurRadius: 8.0,
                            ),
                          ],
                        ),
                  ),

                // Subtitle Widget
                if (widget.subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  if (widget.subtitle is Widget)
                    widget.subtitle as Widget
                  else if (widget.subtitle is String)
                    Text(
                      widget.subtitle as String,
                      textAlign: widget.textAlign,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: widget.subtitleStyle ??
                          const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                            color: AppColors.textSecondary,
                          ),
                    ),
                ],
              ],
            ),
          ),
          if (widget.trailing != null) ...<Widget>[
            const SizedBox(width: 8),
            widget.trailing!,
          ],
        ],
      ),
    );
  }

  Widget _buildAnimatedRune(Color runeColor, Color glowColor) {
    if (!widget.isAnimated) {
      return Text(
        widget.rune,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: runeColor,
          shadows: <Shadow>[
            Shadow(
              color: glowColor.withValues(alpha: widget.glowIntensity * 0.7),
              blurRadius: 8.0 * widget.glowIntensity,
            ),
          ],
        ),
      );
    }

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, _) {
        final double factor = _glowAnimation.value;
        return Text(
          widget.rune,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color.lerp(runeColor, AppColors.goldLight, factor * 0.4) ?? runeColor,
            shadows: <Shadow>[
              Shadow(
                color: glowColor.withValues(
                  alpha: (widget.glowIntensity * factor * 0.8).clamp(0.0, 1.0),
                ),
                blurRadius: 10.0 * factor * widget.glowIntensity,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWing({required bool isLeft, required Color color}) {
    return CustomPaint(
      size: const Size(36, 10),
      painter: _RunicWingPainter(
        isLeft: isLeft,
        color: color,
        style: widget.wingsStyle,
      ),
    );
  }
}

class _RunicWingPainter extends CustomPainter {
  const _RunicWingPainter({
    required this.isLeft,
    required this.color,
    required this.style,
  });

  final bool isLeft;
  final Color color;
  final RunicWingsStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final double dir = isLeft ? -1.0 : 1.0;
    final double startX = isLeft ? size.width : 0.0;
    final double centerY = size.height / 2;

    final Paint linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: isLeft ? Alignment.centerRight : Alignment.centerLeft,
        end: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        colors: <Color>[
          color.withValues(alpha: 0.95),
          color.withValues(alpha: 0.40),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);

    // Main tapering wing whisker
    final Path wingPath = Path()
      ..moveTo(startX, centerY)
      ..cubicTo(
        startX + 14 * dir,
        centerY - 3.5,
        startX + 24 * dir,
        centerY - 2.0,
        startX + 34 * dir,
        centerY + 1.0,
      );
    canvas.drawPath(wingPath, linePaint);

    if (style == RunicWingsStyle.metallic || style == RunicWingsStyle.gem) {
      // Lower parallel blade
      final Path subPath = Path()
        ..moveTo(startX + 4 * dir, centerY + 2.0)
        ..lineTo(startX + 22 * dir, centerY + 2.0);
      canvas.drawPath(subPath, linePaint..strokeWidth = 0.8);
    }

    if (style == RunicWingsStyle.gem) {
      // Tiny decorative diamond node on wing
      final Paint gemPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = color;
      final double gx = startX + 10 * dir;
      final double gy = centerY;
      final Path gem = Path()
        ..moveTo(gx, gy - 2.5)
        ..lineTo(gx + 2.5, gy)
        ..lineTo(gx, gy + 2.5)
        ..lineTo(gx - 2.5, gy)
        ..close();
      canvas.drawPath(gem, gemPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RunicWingPainter oldDelegate) {
    return oldDelegate.isLeft != isLeft ||
        oldDelegate.color != color ||
        oldDelegate.style != style;
  }
}
