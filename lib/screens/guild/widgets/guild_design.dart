import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_text_styles.dart';

/// Lonca ekranı — 2027 Aion 2 Dark Celestial & Iridescent Palette.
abstract final class GuildPalette {
  // Existing tokens preserved for full backward compatibility
  static const Color void_ = AppColors.carbonVoid;
  static const Color navy = AppColors.spaceNavy;
  static const Color surface = Color(0xFF161D2E);
  static const Color surfaceHi = Color(0xFF1E2740);
  static const Color obsidian = AppColors.darkObsidian;
  static const Color titanium = AppColors.mutedTitanium;
  static const Color gold = AppColors.liquidGold;
  static const Color fuchsia = AppColors.cyberFuchsia;
  static const Color ruby = AppColors.mysticRuby;
  static const Color neon = AppColors.toxicNeon;
  static const Color coral = AppColors.coralFlare;
  static const Color solar = AppColors.warningSolar;
  static const Color textHi = AppColors.textPrimary;
  static const Color textMid = AppColors.textSecondary;
  static const Color textLow = AppColors.textTertiary;

  // 2027 Aion 2 Dark Celestial & Iridescent Extensions
  static const Color celestialVoid = Color(0xFF0A0D16);
  static const Color celestialSurface = Color(0xFF111728);
  static const Color iridescentCyan = Color(0xFF00E5FF);
  static const Color iridescentViolet = Color(0xFFA855F7);
  static const Color iridescentRose = Color(0xFFFF2E93);
  static const Color celestialGold = Color(0xFFFFD54F);
  static const Color astralBlue = Color(0xFF3B82F6);

  static const LinearGradient goldGrad = LinearGradient(
    colors: <Color>[Color(0xFFFFD64A), gold, Color(0xFFE08A00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fuchsiaGrad = LinearGradient(
    colors: <Color>[Color(0xFFFF4D7A), fuchsia, Color(0xFF9B1040)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient iridescentGrad = LinearGradient(
    colors: <Color>[iridescentCyan, iridescentViolet, iridescentRose],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient celestialDarkGrad = LinearGradient(
    colors: <Color>[
      Color(0xDF1E2742),
      Color(0xEB131A2C),
      Color(0xF50B0E17),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Frosted Glassmorphism container with backdrop blur, iridescent luminous border, and celestial aura.
class GuildGlassCard extends StatelessWidget {
  const GuildGlassCard({
    super.key,
    required this.child,
    this.accent = GuildPalette.gold,
    this.padding,
    this.borderRadius,
    this.blurSigma = 12.0,
    this.glow = true,
    this.glowOpacity = 0.16,
    this.borderWidth = 1.2,
    this.customGradient,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final bool glow;
  final double glowOpacity;
  final double borderWidth;
  final Gradient? customGradient;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = borderRadius ?? BorderRadius.circular(AppSpacing.radiusLg);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: glowOpacity),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ]
            : <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding ?? const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: customGradient ??
                  LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      accent.withValues(alpha: 0.08),
                      GuildPalette.celestialSurface.withValues(alpha: 0.85),
                      GuildPalette.celestialVoid.withValues(alpha: 0.92),
                    ],
                    stops: const <double>[0.0, 0.45, 1.0],
                  ),
              border: Border.all(
                color: accent.withValues(alpha: 0.38),
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GuildPressable extends StatefulWidget {
  const GuildPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<GuildPressable> createState() => _GuildPressableState();
}

class _GuildPressableState extends State<GuildPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final bool active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapUp: active ? (_) => setState(() => _down = false) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

class GuildNeonPanel extends StatelessWidget {
  const GuildNeonPanel({
    super.key,
    required this.child,
    this.accent = GuildPalette.gold,
    this.padding,
    this.glow = true,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry? padding;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return GuildGlassCard(
      accent: accent,
      padding: padding,
      glow: glow,
      child: child,
    );
  }
}

class GuildSectionTitle extends StatelessWidget {
  const GuildSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.accent = GuildPalette.gold,
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
        // Glowing Iridescent Diamond Accent
        Container(
          width: 8,
          height: 8,
          transform: Matrix4.rotationZ(0.785398), // 45 degrees diamond
          decoration: BoxDecoration(
            color: accent,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.75),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: AppTextStyles.h3.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: GuildPalette.textHi,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTextStyles.caption.copyWith(
                    color: GuildPalette.titanium,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class GuildStatPill extends StatelessWidget {
  const GuildStatPill({
    super.key,
    required this.icon,
    required this.label,
    this.accent = GuildPalette.titanium,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? accent.withValues(alpha: 0.18)
            : GuildPalette.celestialVoid.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: filled ? 0.55 : 0.35),
          width: 1.0,
        ),
        boxShadow: filled
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: filled ? accent : GuildPalette.textHi,
            ),
          ),
        ],
      ),
    );
  }
}

class GuildActionTile extends StatelessWidget {
  const GuildActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
    this.filled = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GuildPressable(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 88),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          gradient: filled
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    accent.withValues(alpha: 0.85),
                    accent.withValues(alpha: 0.55),
                    GuildPalette.navy,
                  ],
                )
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    GuildPalette.surfaceHi.withValues(alpha: 0.9),
                    GuildPalette.celestialVoid.withValues(alpha: 0.95),
                  ],
                ),
          border: Border.all(
            color: accent.withValues(alpha: filled ? 0.75 : 0.42),
            width: 1.2,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: (filled ? Colors.black : accent).withValues(alpha: filled ? 0.25 : 0.16),
                border: Border.all(color: accent.withValues(alpha: 0.5)),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(icon, size: 18, color: filled ? GuildPalette.textHi : accent),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.2,
                color: filled ? GuildPalette.void_ : GuildPalette.textHi,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: filled
                    ? GuildPalette.void_.withValues(alpha: 0.75)
                    : GuildPalette.titanium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GuildProgressStrip extends StatelessWidget {
  const GuildProgressStrip({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    this.accent = GuildPalette.neon,
  });

  final String label;
  final double value;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: GuildPalette.titanium,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              detail,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 7,
            child: Stack(
              children: <Widget>[
                Container(color: GuildPalette.obsidian),
                FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[accent.withValues(alpha: 0.55), accent],
                      ),
                      boxShadow: <BoxShadow>[
                        BoxShadow(color: accent.withValues(alpha: 0.45), blurRadius: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
