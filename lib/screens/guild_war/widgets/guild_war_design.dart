import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../components/layout/game_chrome.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../theme/app_colors.dart';

/// Lonca Savaşı — yalnızca [AppColors] paleti.
abstract final class WarPalette {
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

  static const LinearGradient goldGrad = AppColors.liquidGoldGradient;

  static const LinearGradient attackGrad = LinearGradient(
    colors: <Color>[AppColors.mysticRuby, AppColors.coralFlare],
  );

  static const LinearGradient backdropGrad = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[AppColors.carbonVoid, AppColors.spaceNavy, AppColors.carbonVoid],
  );

  static LinearGradient heroGrad(Color accent) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: <Color>[
          accent.withValues(alpha: 0.20),
          AppColors.spaceNavy,
          AppColors.carbonVoid,
        ],
      );

  static LinearGradient surfaceGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      AppColors.spaceNavy.withValues(alpha: 0.95),
      AppColors.carbonVoid.withValues(alpha: 0.98),
    ],
  );
}

/// Noktalı doku — Muted Titanium %5–10 (tasarım skill §3).
class WarDotPainter extends CustomPainter {
  const WarDotPainter({this.spacing = 14, this.opacity = 0.07});

  final double spacing;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = WarPalette.titanium.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WarDotPainter oldDelegate) =>
      spacing != oldDelegate.spacing || opacity != oldDelegate.opacity;
}

/// Full-bleed war backdrop: gradient + titanium dots + glow orbs.
class WarBackdrop extends StatelessWidget {
  const WarBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: WarPalette.backdropGrad),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const CustomPaint(painter: WarDotPainter(spacing: 20, opacity: 0.06)),
          Positioned(
            top: -120,
            right: -80,
            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      WarPalette.fuchsia.withValues(alpha: 0.14),
                      WarPalette.fuchsia.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      WarPalette.gold.withValues(alpha: 0.10),
                      WarPalette.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Press feedback — scale micro-interaction (tasarım skill §5).
class WarPressable extends StatefulWidget {
  const WarPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<WarPressable> createState() => _WarPressableState();
}

class _WarPressableState extends State<WarPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Liste giriş animasyonu — fade + slide up.
class WarFadeSlide extends StatefulWidget {
  const WarFadeSlide({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  @override
  State<WarFadeSlide> createState() => _WarFadeSlideState();
}

class _WarFadeSlideState extends State<WarFadeSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    Future<void>.delayed(Duration(milliseconds: 40 * widget.index), () {
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
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Dotted panel — karakter / envanter popup stili.
class WarDottedPanel extends StatelessWidget {
  const WarDottedPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.borderRadius = 14,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? borderColor;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return DottedPanel(
      padding: padding ?? const EdgeInsets.all(14),
      borderRadius: borderRadius,
      borderColor: borderColor ?? WarPalette.gold.withValues(alpha: 0.28),
      child: child,
    );
  }
}

/// Hero banner — noktalı doku + accent gradient (checker YOK).
class WarHeroBanner extends StatelessWidget {
  const WarHeroBanner({
    super.key,
    required this.child,
    this.accent = WarPalette.fuchsia,
  });

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: WarPalette.heroGrad(accent),
        border: Border.all(color: accent.withValues(alpha: 0.40), width: 1.2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.14),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(painter: WarDotPainter(spacing: 12, opacity: 0.08)),
            ),
            Positioned(
              top: -36,
              right: -16,
              child: IgnorePointer(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[
                        accent.withValues(alpha: 0.24),
                        accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.all(16), child: child),
          ],
        ),
      ),
    );
  }
}

/// Frosted neon kart — içinde noktalı doku.
class WarNeonCard extends StatelessWidget {
  const WarNeonCard({
    super.key,
    required this.child,
    this.accent = WarPalette.gold,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.glow = false,
    this.radius = 16,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool glow;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final Widget card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: WarPalette.surfaceGrad,
        border: Border.all(
          color: glow ? accent.withValues(alpha: 0.55) : accent.withValues(alpha: 0.22),
          width: glow ? 1.4 : 1,
        ),
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.20),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: Stack(
          children: <Widget>[
            const Positioned.fill(
              child: CustomPaint(painter: WarDotPainter(spacing: 13, opacity: 0.055)),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    if (onTap == null) return card;
    return WarPressable(onTap: onTap, child: card);
  }
}

/// Blur dialog — envanter popup stili (sigma 10).
class WarDialog {
  static Future<bool?> confirm({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'İptal',
    Color accent = WarPalette.ruby,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: title,
      barrierColor: AppColors.carbonVoid.withValues(alpha: 0.45),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> secondary) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (BuildContext ctx, Animation<double> anim, Animation<double> secondary, Widget? child) {
        final double scale = Curves.easeOutBack.transform(anim.value);
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: FadeTransition(
            opacity: anim,
            child: Transform.scale(
              scale: scale,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: WarDottedPanel(
                    borderColor: accent.withValues(alpha: 0.45),
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          message,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: WarPalette.titanium,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(
                                  cancelLabel,
                                  style: const TextStyle(color: WarPalette.titanium),
                                ),
                              ),
                            ),
                            Expanded(
                              child: WarGoldButton(
                                label: confirmLabel,
                                onPressed: () => Navigator.pop(ctx, true),
                                expand: true,
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
        );
      },
    );
  }
}

/// Section header — dikey accent bar.
class WarSectionHeader extends StatelessWidget {
  const WarSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.accent = WarPalette.gold,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 4,
          height: 28,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(4),
            boxShadow: <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.55), blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: 0.6,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: WarPalette.titanium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class WarStatusPill extends StatelessWidget {
  const WarStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.pulse = false,
  });

  final String label;
  final Color color;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.55)),
        boxShadow: pulse
            ? <BoxShadow>[BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 10)]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (pulse)
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class WarFilterChip extends StatelessWidget {
  const WarFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = WarPalette.gold,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return WarPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: <Color>[
                    accent.withValues(alpha: 0.22),
                    WarPalette.navy.withValues(alpha: 0.8),
                  ],
                )
              : null,
          color: selected ? null : WarPalette.obsidian.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accent.withValues(alpha: 0.65) : WarPalette.obsidian,
          ),
          boxShadow: selected
              ? <BoxShadow>[BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 12)]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? accent : WarPalette.titanium,
          ),
        ),
      ),
    );
  }
}

class WarGoldButton extends StatelessWidget {
  const WarGoldButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget btn = WarPressable(
      enabled: onPressed != null,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null ? WarPalette.goldGrad : null,
          color: onPressed == null ? WarPalette.obsidian : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed != null
              ? <BoxShadow>[
                  BoxShadow(
                    color: WarPalette.gold.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 16, color: WarPalette.void_),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: onPressed != null ? WarPalette.void_ : WarPalette.titanium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class WarOutlineButton extends StatelessWidget {
  const WarOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.accent = WarPalette.gold,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget btn = WarPressable(
      enabled: onPressed != null,
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.50)),
          gradient: LinearGradient(
            colors: <Color>[
              WarPalette.navy.withValues(alpha: 0.6),
              WarPalette.void_.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          children: <Widget>[
            Icon(icon ?? Icons.arrow_forward_rounded, size: 15, color: accent),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: accent),
            ),
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

class WarAttackButton extends StatelessWidget {
  const WarAttackButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return WarPressable(
      enabled: onPressed != null,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null ? WarPalette.attackGrad : null,
          color: onPressed == null ? WarPalette.obsidian : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: onPressed != null
              ? <BoxShadow>[BoxShadow(color: WarPalette.ruby.withValues(alpha: 0.30), blurRadius: 12)]
              : null,
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              'SALDIR',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WarDefenseButton extends StatelessWidget {
  const WarDefenseButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return WarPressable(
      enabled: onPressed != null,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onPressed != null
              ? LinearGradient(
                  colors: <Color>[
                    WarPalette.neon.withValues(alpha: 0.22),
                    WarPalette.navy.withValues(alpha: 0.9),
                  ],
                )
              : null,
          color: onPressed == null ? WarPalette.obsidian : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: onPressed != null ? WarPalette.neon.withValues(alpha: 0.60) : WarPalette.obsidian,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              'SAVUNMA EKLE',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: onPressed != null ? WarPalette.neon : WarPalette.titanium,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WarStatChip extends StatelessWidget {
  const WarStatChip({
    super.key,
    required this.emoji,
    required this.label,
    this.accent = WarPalette.gold,
  });

  final String emoji;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$emoji $label',
        style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class WarEmptyTab extends StatelessWidget {
  const WarEmptyTab({
    super.key,
    required this.icon,
    required this.message,
  });

  final String icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return WarDottedPanel(
      borderColor: WarPalette.titanium.withValues(alpha: 0.25),
      child: Row(
        children: <Widget>[
          Text(icon, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: WarPalette.titanium,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double warBottomInset(BuildContext context) => gameBottomBarClearance(context);
