import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/layout/game_screen_background.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Bildirim UI — /tasarim: Carbon Void, dot doku, Liquid Gold, Cyber Fuchsia.
abstract final class NotificationDesign {
  static const Color void_ = AppColors.carbonVoid;
  static const Color navy = AppColors.spaceNavy;
  static const Color obsidian = AppColors.darkObsidian;
  static const Color titanium = AppColors.mutedTitanium;
  static const Color gold = AppColors.liquidGold;
  static const Color fuchsia = AppColors.cyberFuchsia;
  static const Color ruby = AppColors.mysticRuby;
  static const Color neon = AppColors.toxicNeon;
  static const Color coral = AppColors.coralFlare;
  static const Color solar = AppColors.warningSolar;
  static const Color textHi = AppColors.textPrimary;

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFFD64A), AppColors.liquidGold, Color(0xFFE08A00)],
    stops: <double>[0.0, 0.52, 1.0],
  );

  static const LinearGradient fuchsiaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0xFFFF4D8D), AppColors.cyberFuchsia, Color(0xFF9B1440)],
  );

  static TextStyle panelTitle({Color color = gold}) => GoogleFonts.urbanist(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: color,
      );

  static TextStyle sectionCaps({Color color = titanium}) => GoogleFonts.urbanist(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.8,
        color: color,
      );

  static TextStyle tileTitle({Color color = textHi}) => GoogleFonts.urbanist(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
      );

  static TextStyle tileBody({Color color = titanium}) => GoogleFonts.urbanist(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.35,
        color: color,
      );
}

class NotificationPressable extends StatefulWidget {
  const NotificationPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<NotificationPressable> createState() => _NotificationPressableState();
}

class _NotificationPressableState extends State<NotificationPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _pressed = true) : null,
      onTapUp: active ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: active ? () => setState(() => _pressed = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class NotificationGlassShell extends StatelessWidget {
  const NotificationGlassShell({
    super.key,
    required this.child,
    this.compactTopRadius = true,
    this.accent = NotificationDesign.gold,
  });

  final Widget child;
  final bool compactTopRadius;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = compactTopRadius
        ? const BorderRadius.vertical(top: Radius.circular(24))
        : BorderRadius.zero;

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: accent.withValues(alpha: 0.28), width: 1.2),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                NotificationDesign.navy.withValues(alpha: 0.94),
                NotificationDesign.void_.withValues(alpha: 0.98),
              ],
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 28,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Stack(
            children: <Widget>[
              const Positioned.fill(
                child: CustomPaint(
                  painter: DotGridPainter(spacing: 14, dotOpacity: 0.065),
                ),
              ),
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                child: IgnorePointer(
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          accent.withValues(alpha: 0.65),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: -40,
                right: -20,
                child: IgnorePointer(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: <Color>[
                          NotificationDesign.fuchsia.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationFadeSlide extends StatefulWidget {
  const NotificationFadeSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.index = 0,
  });

  final Widget child;
  final Duration delay;
  final int index;

  @override
  State<NotificationFadeSlide> createState() => _NotificationFadeSlideState();
}

class _NotificationFadeSlideState extends State<NotificationFadeSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

  @override
  void initState() {
    super.initState();
    final Duration stagger = Duration(milliseconds: 40 * widget.index);
    Future<void>.delayed(widget.delay + stagger, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class NotificationGoldButton extends StatelessWidget {
  const NotificationGoldButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return NotificationPressable(
      onTap: onPressed,
      enabled: onPressed != null,
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: onPressed != null ? NotificationDesign.goldGradient : null,
          color: onPressed == null ? NotificationDesign.obsidian : null,
          boxShadow: onPressed != null
              ? <BoxShadow>[
                  BoxShadow(
                    color: NotificationDesign.gold.withValues(alpha: 0.32),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.urbanist(
            color: NotificationDesign.void_,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class NotificationSectionHeader extends StatelessWidget {
  const NotificationSectionHeader({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              gradient: NotificationDesign.goldGradient,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: NotificationDesign.gold.withValues(alpha: 0.45),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(label.toUpperCase(), style: NotificationDesign.sectionCaps()),
        ],
      ),
    );
  }
}
