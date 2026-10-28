import 'package:flutter/material.dart';

import '../../../components/common/adaptive_glass_blur.dart';
import '../../../components/layout/game_screen_background.dart';
import '../../../core/services/app_haptics.dart';
import '../../../core/services/graphics_quality_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

/// Settings-only tasarim tokens (tasarim skill palette).
abstract final class SettingsPalette {
  static const Color void_ = AppColors.carbonVoid;
  static const Color navy = AppColors.spaceNavy;
  static const Color obsidian = AppColors.darkObsidian;
  static const Color titanium = AppColors.mutedTitanium;
  static const Color gold = AppColors.liquidGold;
  static const Color fuchsia = AppColors.cyberFuchsia;
  static const Color neon = AppColors.toxicNeon;
  static const Color ruby = AppColors.mysticRuby;
  static const Color coral = AppColors.coralFlare;
  static const Color textHi = Color(0xFFF2F6FF);
  static const Color textMid = Color(0xFFA9B7D0);
}

/// Scale press feedback.
class SettingsPressable extends StatefulWidget {
  const SettingsPressable({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<SettingsPressable> createState() => _SettingsPressableState();
}

class _SettingsPressableState extends State<SettingsPressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.enabled && widget.onTap != null
          ? (_) => setState(() => _down = true)
          : null,
      onTapUp: widget.enabled && widget.onTap != null
          ? (_) => setState(() => _down = false)
          : null,
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.enabled
          ? () {
              AppHaptics.selection();
              widget.onTap?.call();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Glass hero / section shell with dot mesh + glow border.
class SettingsGlassCard extends StatelessWidget {
  const SettingsGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent = SettingsPalette.gold,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accent;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final GraphicsProfile prof = GraphicsQualityService.instance.profile;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AdaptiveGlassBlur(
        sigma: 10,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                SettingsPalette.navy.withValues(alpha: 0.94),
                SettingsPalette.void_.withValues(alpha: 0.98),
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.32)),
            boxShadow: (glow && prof.enableHeavyShadows)
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: <Widget>[
              if (prof.enableDotGridOverlay)
                const Positioned.fill(
                  child: CustomPaint(
                    painter: DotGridPainter(spacing: 14, dotOpacity: 0.06),
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  const SettingsSectionHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.accent = SettingsPalette.gold,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                accent.withValues(alpha: 0.35),
                SettingsPalette.obsidian,
              ],
            ),
            border: Border.all(color: accent.withValues(alpha: 0.45)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accent.withValues(alpha: 0.25),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(icon, size: 18, color: accent),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title.toUpperCase(),
                style: AppTextStyles.captionBold.copyWith(
                  color: SettingsPalette.textHi,
                  letterSpacing: 1.0,
                  fontSize: 12,
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.titanium,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Neon pill toggle — on = Toxic Neon glow.
class SettingsNeonToggle extends StatelessWidget {
  const SettingsNeonToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null;
    final Color track = value
        ? SettingsPalette.neon.withValues(alpha: enabled ? 0.85 : 0.35)
        : SettingsPalette.obsidian;
    final Color thumb = value ? SettingsPalette.textHi : SettingsPalette.titanium;

    return SettingsPressable(
      enabled: enabled,
      onTap: enabled
          ? () {
              onChanged!(!value);
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: track,
          border: Border.all(
            color: value
                ? SettingsPalette.neon.withValues(alpha: 0.9)
                : SettingsPalette.titanium.withValues(alpha: 0.35),
          ),
          boxShadow: value && enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: SettingsPalette.neon.withValues(alpha: 0.45),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: thumb,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsToggleRow extends StatelessWidget {
  const SettingsToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.icon,
    this.indent = false,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final bool indent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent ? 12 : 0, top: 6, bottom: 6),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 18, color: SettingsPalette.titanium),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: AppTextStyles.body.copyWith(
                    color: SettingsPalette.textHi,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.caption.copyWith(
                      color: SettingsPalette.titanium,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          SettingsNeonToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Gold-gradient volume slider.
class SettingsVolumeSlider extends StatelessWidget {
  const SettingsVolumeSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon = Icons.volume_up_rounded,
    this.enabled = true,
  });

  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final IconData icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final double display = enabled ? value : 0;
    final int pct = (display * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                icon,
                size: 16,
                color: enabled ? SettingsPalette.gold : SettingsPalette.titanium,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.body.copyWith(
                    color: enabled
                        ? SettingsPalette.textHi
                        : SettingsPalette.titanium,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: AppTextStyles.captionBold.copyWith(
                  color: enabled ? SettingsPalette.gold : SettingsPalette.titanium,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: SettingsPalette.gold,
              inactiveTrackColor: SettingsPalette.obsidian,
              thumbColor: SettingsPalette.gold,
              overlayColor: SettingsPalette.gold.withValues(alpha: 0.2),
              disabledActiveTrackColor:
                  SettingsPalette.titanium.withValues(alpha: 0.25),
              disabledInactiveTrackColor: SettingsPalette.obsidian,
              disabledThumbColor: SettingsPalette.titanium,
            ),
            child: Slider(
              value: display.clamp(0.0, 1.0),
              onChanged: enabled
                  ? (double v) {
                      AppHaptics.selection();
                      onChanged?.call(v);
                    }
                  : null,
              min: 0,
              max: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPrimaryButton extends StatelessWidget {
  const SettingsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SettingsPressable(
      enabled: onPressed != null && !loading,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: onPressed == null || loading
              ? null
              : const LinearGradient(
                  colors: <Color>[
                    Color(0xFFFFD64A),
                    AppColors.liquidGold,
                    Color(0xFFE08A00),
                  ],
                ),
          color: onPressed == null || loading ? SettingsPalette.obsidian : null,
          boxShadow: onPressed != null && !loading
              ? <BoxShadow>[
                  BoxShadow(
                    color: SettingsPalette.gold.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SettingsPalette.void_,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 18, color: SettingsPalette.void_),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: SettingsPalette.void_,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class SettingsOutlineButton extends StatelessWidget {
  const SettingsOutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.accent = SettingsPalette.titanium,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SettingsPressable(
      enabled: onPressed != null,
      onTap: onPressed,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: SettingsPalette.navy.withValues(alpha: 0.6),
          border: Border.all(color: accent.withValues(alpha: 0.55)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTextStyles.bodyBold.copyWith(
                color: SettingsPalette.textHi,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsDangerButton extends StatelessWidget {
  const SettingsDangerButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SettingsPressable(
      enabled: onPressed != null,
      onTap: onPressed,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            colors: <Color>[
              SettingsPalette.ruby.withValues(alpha: 0.95),
              SettingsPalette.fuchsia.withValues(alpha: 0.9),
            ],
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: SettingsPalette.ruby.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 18, color: SettingsPalette.textHi),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: AppTextStyles.bodyBold.copyWith(
                color: SettingsPalette.textHi,
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fade+slide entrance for list sections.
class SettingsStagger extends StatelessWidget {
  const SettingsStagger({
    super.key,
    required this.index,
    required this.child,
    this.reduceMotion = false,
  });

  final int index;
  final Widget child;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    if (reduceMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index * 55).clamp(0, 280)),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double t, Widget? child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
