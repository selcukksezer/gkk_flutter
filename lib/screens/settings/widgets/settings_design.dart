import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/services/app_haptics.dart';
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

  // Surface elevation hierarchy
  static const Color surface0 = AppColors.bgDeep;
  static const Color surface1 = AppColors.bgBase;
  static const Color surface2 = AppColors.bgSurface;
  static const Color surface3 = AppColors.bgCard;
  static const Color surfaceElevated = AppColors.bgCardElevated;

  // Text hierarchy
  static const Color textDim = Color(0xFF6B7A99);
  static const Color textMuted = AppColors.mutedTitanium;

  // Border tokens
  static const Color borderFaint = Color(0xFF1A2540);
  static const Color borderDefault = Color(0xFF253154);
  static const Color borderBright = Color(0xFF3B4D70);
  static const Color borderGold = Color(0x66FFB800);
  static const Color borderNeon = Color(0x6600FF66);

  // AAA Gradients
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xFFFFD64A),
      AppColors.liquidGold,
      Color(0xFFE08A00),
    ],
  );

  static const LinearGradient rubyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      AppColors.mysticRuby,
      AppColors.cyberFuchsia,
    ],
  );

  static const LinearGradient neonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      AppColors.toxicNeon,
      Color(0xFF00D1FF),
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[
      Color(0xEA121826),
      Color(0xF5080B12),
    ],
  );
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

class DotGridPainter extends CustomPainter {
  const DotGridPainter({
    this.spacing = 16,
    this.dotRadius = 1.1,
    this.dotOpacity = 0.07,
  });

  final double spacing;
  final double dotRadius;
  final double dotOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white.withValues(alpha: dotOpacity)
      ..style = PaintingStyle.fill;

    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DotGridPainter oldDelegate) =>
      oldDelegate.spacing != spacing ||
      oldDelegate.dotRadius != dotRadius ||
      oldDelegate.dotOpacity != dotOpacity;
}

/// Subtle corner notch painter for dark fantasy luxury panels.
class SettingsRunicCornerPainter extends CustomPainter {
  const SettingsRunicCornerPainter({
    this.color = const Color(0x33FFFFFF),
    this.notchLength = 8.0,
    this.inset = 4.0,
    this.strokeWidth = 1.0,
  });

  final Color color;
  final double notchLength;
  final double inset;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Top-left notch
    canvas.drawLine(Offset(inset, inset + notchLength), Offset(inset, inset), paint);
    canvas.drawLine(Offset(inset, inset), Offset(inset + notchLength, inset), paint);
    // Top-right notch
    canvas.drawLine(Offset(size.width - inset - notchLength, inset), Offset(size.width - inset, inset), paint);
    canvas.drawLine(Offset(size.width - inset, inset), Offset(size.width - inset, inset + notchLength), paint);
    // Bottom-left notch
    canvas.drawLine(Offset(inset, size.height - inset - notchLength), Offset(inset, size.height - inset), paint);
    canvas.drawLine(Offset(inset, size.height - inset), Offset(inset + notchLength, size.height - inset), paint);
    // Bottom-right notch
    canvas.drawLine(Offset(size.width - inset - notchLength, size.height - inset), Offset(size.width - inset, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset, size.height - inset), Offset(size.width - inset, size.height - inset - notchLength), paint);
  }

  @override
  bool shouldRepaint(covariant SettingsRunicCornerPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.notchLength != notchLength ||
      oldDelegate.inset != inset ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// Glass hero / section shell with dot mesh, specular rim light, and outward glow border.
class SettingsGlassCard extends StatelessWidget {
  const SettingsGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accent = SettingsPalette.gold,
    this.glow = false,
    this.hasRunicBorders = false,
    this.showSpecularHighlight = true,
    this.hasDotMesh = true,
    this.borderRadius = 18.0,
    this.blurSigma = 10.0,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color accent;
  final bool glow;
  final bool hasRunicBorders;
  final bool showSpecularHighlight;
  final bool hasDotMesh;
  final double borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(borderRadius);

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 24,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  SettingsPalette.navy.withValues(alpha: 0.92),
                  SettingsPalette.void_.withValues(alpha: 0.96),
                ],
              ),
              border: Border.all(
                color: accent.withValues(alpha: 0.35),
                width: 1.1,
              ),
            ),
            child: Stack(
              children: <Widget>[
                if (hasDotMesh)
                  const Positioned.fill(
                    child: CustomPaint(
                      painter: DotGridPainter(spacing: 14, dotOpacity: 0.06),
                    ),
                  ),
                if (showSpecularHighlight)
                  Positioned(
                    top: 0,
                    left: 14,
                    right: 14,
                    height: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.transparent,
                            accent.withValues(alpha: 0.55),
                            Colors.white.withValues(alpha: 0.4),
                            accent.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                if (hasRunicBorders)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: SettingsRunicCornerPainter(
                        color: accent.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                Padding(padding: padding, child: child),
              ],
            ),
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
    this.badgeText,
    this.badgeColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;
  final String? badgeText;
  final Color? badgeColor;
  final Widget? trailing;

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
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      title.toUpperCase(),
                      style: AppTextStyles.captionBold.copyWith(
                        color: SettingsPalette.textHi,
                        letterSpacing: 1.0,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badgeText != null) ...<Widget>[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? accent).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (badgeColor ?? accent).withValues(alpha: 0.55),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        badgeText!,
                        style: AppTextStyles.captionBold.copyWith(
                          color: badgeColor ?? accent,
                          fontSize: 8.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ],
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
        if (trailing != null) ...<Widget>[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

/// Neon pill toggle — on = Toxic Neon glow (or custom accent).
class SettingsNeonToggle extends StatelessWidget {
  const SettingsNeonToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.accent = SettingsPalette.neon,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null;
    final Color track = value
        ? accent.withValues(alpha: enabled ? 0.85 : 0.35)
        : SettingsPalette.obsidian;
    final Color thumb =
        value ? SettingsPalette.textHi : SettingsPalette.titanium;

    return SettingsPressable(
      enabled: enabled,
      onTap: enabled
          ? () {
              AppHaptics.selection();
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
                ? accent.withValues(alpha: 0.9)
                : SettingsPalette.titanium.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: value && enabled
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 12,
                    spreadRadius: 0.5,
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
                  color: Colors.black.withValues(alpha: 0.4),
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
    this.accent = SettingsPalette.neon,
    this.badgeText,
    this.badgeColor,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final IconData? icon;
  final bool indent;
  final Color accent;
  final String? badgeText;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: indent ? 12 : 0, top: 6, bottom: 6),
      child: Row(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: (value ? accent : SettingsPalette.titanium)
                    .withValues(alpha: 0.12),
                border: Border.all(
                  color: (value ? accent : SettingsPalette.titanium)
                      .withValues(alpha: 0.28),
                ),
              ),
              child: Icon(
                icon,
                size: 16,
                color: value ? accent : SettingsPalette.titanium,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        title,
                        style: AppTextStyles.body.copyWith(
                          color: SettingsPalette.textHi,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeText != null) ...<Widget>[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: (badgeColor ?? accent).withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (badgeColor ?? accent)
                                .withValues(alpha: 0.55),
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          badgeText!,
                          style: AppTextStyles.captionBold.copyWith(
                            color: badgeColor ?? accent,
                            fontSize: 8.5,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
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
          SettingsNeonToggle(
            value: value,
            onChanged: onChanged,
            accent: accent,
          ),
        ],
      ),
    );
  }
}

/// Dark fantasy volume slider with gold/accent glow and tactile haptic feedback.
class SettingsVolumeSlider extends StatelessWidget {
  const SettingsVolumeSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon = Icons.volume_up_rounded,
    this.enabled = true,
    this.accent = SettingsPalette.gold,
    this.divisions,
    this.valueFormatter,
  });

  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final IconData icon;
  final bool enabled;
  final Color accent;
  final int? divisions;
  final String Function(double)? valueFormatter;

  @override
  Widget build(BuildContext context) {
    final double display = enabled ? value : 0;
    final String displayStr = valueFormatter != null
        ? valueFormatter!(display)
        : '${(display * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: (enabled ? accent : SettingsPalette.titanium)
                      .withValues(alpha: 0.12),
                  border: Border.all(
                    color: (enabled ? accent : SettingsPalette.titanium)
                        .withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: enabled ? accent : SettingsPalette.titanium,
                ),
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
                displayStr,
                style: AppTextStyles.captionBold.copyWith(
                  color: enabled ? accent : SettingsPalette.titanium,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 9,
                pressedElevation: 4,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: accent,
              inactiveTrackColor: SettingsPalette.obsidian,
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.2),
              disabledActiveTrackColor:
                  SettingsPalette.titanium.withValues(alpha: 0.25),
              disabledInactiveTrackColor: SettingsPalette.obsidian,
              disabledThumbColor: SettingsPalette.titanium,
            ),
            child: Slider(
              value: display.clamp(0.0, 1.0),
              divisions: divisions,
              onChanged: enabled
                  ? (double v) {
                      if ((v * 20).round() != (value * 20).round()) {
                        AppHaptics.selection();
                      }
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

/// Generic slider tile for graphics, gameplay, and system tuning parameters.
class SettingsSliderTile extends StatelessWidget {
  const SettingsSliderTile({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.divisions,
    this.icon,
    this.subtitle,
    this.valueLabel,
    this.accent = SettingsPalette.gold,
    this.enabled = true,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double>? onChanged;
  final int? divisions;
  final IconData? icon;
  final String? subtitle;
  final String? valueLabel;
  final Color accent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final double clampedVal = value.clamp(min, max);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: (enabled ? accent : SettingsPalette.titanium)
                        .withValues(alpha: 0.12),
                    border: Border.all(
                      color: (enabled ? accent : SettingsPalette.titanium)
                          .withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 15,
                    color: enabled ? accent : SettingsPalette.titanium,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: AppTextStyles.body.copyWith(
                        color: enabled
                            ? SettingsPalette.textHi
                            : SettingsPalette.titanium,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
              Text(
                valueLabel ?? clampedVal.toStringAsFixed(1),
                style: AppTextStyles.captionBold.copyWith(
                  color: enabled ? accent : SettingsPalette.titanium,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(
                enabledThumbRadius: 9,
                pressedElevation: 4,
              ),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: accent,
              inactiveTrackColor: SettingsPalette.obsidian,
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.2),
              disabledActiveTrackColor:
                  SettingsPalette.titanium.withValues(alpha: 0.25),
              disabledInactiveTrackColor: SettingsPalette.obsidian,
              disabledThumbColor: SettingsPalette.titanium,
            ),
            child: Slider(
              value: clampedVal,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled
                  ? (double v) {
                      AppHaptics.selection();
                      onChanged?.call(v);
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centralized Material 3 Theme helpers for Settings screens.
/// Guarantees state-mapped WidgetStateProperty definitions and prevents deprecated
/// property usages (e.g. activeThumbColor).
abstract final class SettingsTheme {
  /// Theme data for standard Flutter [Switch] widgets in Settings.
  static SwitchThemeData switchTheme({Color accent = SettingsPalette.neon}) {
    return SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return SettingsPalette.titanium.withValues(alpha: 0.4);
          }
          if (states.contains(WidgetState.selected)) {
            return SettingsPalette.textHi;
          }
          return SettingsPalette.titanium;
        },
      ),
      trackColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.disabled)) {
            return SettingsPalette.obsidian.withValues(alpha: 0.3);
          }
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.85);
          }
          return SettingsPalette.obsidian;
        },
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.9);
          }
          return SettingsPalette.titanium.withValues(alpha: 0.35);
        },
      ),
      overlayColor: WidgetStateProperty.resolveWith<Color>(
        (Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return accent.withValues(alpha: 0.15);
          }
          return Colors.transparent;
        },
      ),
    );
  }

  /// Theme data for standard Flutter [Slider] widgets in Settings.
  static SliderThemeData sliderTheme(
    BuildContext context, {
    Color accent = SettingsPalette.gold,
  }) {
    return SliderTheme.of(context).copyWith(
      trackHeight: 6,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      activeTrackColor: accent,
      inactiveTrackColor: SettingsPalette.obsidian,
      thumbColor: accent,
      overlayColor: accent.withValues(alpha: 0.2),
      disabledActiveTrackColor:
          SettingsPalette.titanium.withValues(alpha: 0.25),
      disabledInactiveTrackColor: SettingsPalette.obsidian,
      disabledThumbColor: SettingsPalette.titanium,
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
    this.accent = SettingsPalette.gold,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final bool active = onPressed != null && !loading;

    return SettingsPressable(
      enabled: active,
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: active
              ? const LinearGradient(
                  colors: <Color>[
                    Color(0xFFFFD64A),
                    AppColors.liquidGold,
                    Color(0xFFE08A00),
                  ],
                )
              : null,
          color: active ? null : SettingsPalette.obsidian,
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: accent.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (active)
                Positioned(
                  top: 0,
                  left: 12,
                  right: 12,
                  height: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
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
            ],
          ),
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
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
    final bool active = onPressed != null;

    return SettingsPressable(
      enabled: active,
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
          boxShadow: active
              ? <BoxShadow>[
                  BoxShadow(
                    color: SettingsPalette.ruby.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (active)
                Positioned(
                  top: 0,
                  left: 12,
                  right: 12,
                  height: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              Row(
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
            ],
          ),
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

/// AAA Dark Fantasy segmented toggle for graphics / performance / sound presets.
class SettingsSegmentedControl<T> extends StatelessWidget {
  const SettingsSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.accent = SettingsPalette.gold,
    this.enabled = true,
  });

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onSelected;
  final Color accent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: SettingsPalette.obsidian.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: SettingsPalette.titanium.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: segments.entries.map((MapEntry<T, String> entry) {
          final bool isSelected = entry.key == selected;
          return Expanded(
            child: SettingsPressable(
              enabled: enabled,
              onTap: isSelected ? null : () => onSelected(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: isSelected
                      ? LinearGradient(
                          colors: <Color>[
                            accent.withValues(alpha: 0.35),
                            accent.withValues(alpha: 0.15),
                          ],
                        )
                      : null,
                  border: isSelected
                      ? Border.all(
                          color: accent.withValues(alpha: 0.8),
                          width: 1.2,
                        )
                      : Border.all(color: Colors.transparent, width: 1.2),
                  boxShadow: isSelected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  entry.value,
                  style: AppTextStyles.captionBold.copyWith(
                    color: isSelected
                        ? (enabled
                            ? SettingsPalette.textHi
                            : SettingsPalette.titanium)
                        : SettingsPalette.titanium,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Standardized AAA section card with glassmorphism, runic corners, and integrated header.
class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.subtitle,
    this.accent = SettingsPalette.gold,
    this.glow = false,
    this.hasRunicBorders = false,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;
  final String? subtitle;
  final Color accent;
  final bool glow;
  final bool hasRunicBorders;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SettingsGlassCard(
      accent: accent,
      glow: glow,
      hasRunicBorders: hasRunicBorders,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            SettingsSectionHeader(
              icon: icon!,
              title: title,
              subtitle: subtitle,
              accent: accent,
              trailing: trailing,
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.transparent,
                    accent.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          ...children,
        ],
      ),
    );
  }
}

/// Luminous radio option for settings selection lists.
class SettingsRadioTile<T> extends StatelessWidget {
  const SettingsRadioTile({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.accent = SettingsPalette.gold,
    this.enabled = true,
  });

  final T value;
  final T groupValue;
  final ValueChanged<T>? onChanged;
  final String title;
  final String? subtitle;
  final Color accent;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = value == groupValue;
    return SettingsPressable(
      enabled: enabled && onChanged != null,
      onTap: () => onChanged?.call(value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: <Widget>[
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? accent
                      : SettingsPalette.titanium.withValues(alpha: 0.4),
                  width: 1.8,
                ),
                boxShadow: isSelected
                    ? <BoxShadow>[
                        BoxShadow(
                          color: accent.withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              padding: const EdgeInsets.all(3.5),
              child: isSelected
                  ? Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accent,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: AppTextStyles.body.copyWith(
                      color: isSelected
                          ? SettingsPalette.textHi
                          : SettingsPalette.textMid,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13.5,
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
        ),
      ),
    );
  }
}

/// Diagnostic / advisory banner for telemetry, battery tiers, and preloader status.
class SettingsInfoBanner extends StatelessWidget {
  const SettingsInfoBanner({
    super.key,
    required this.message,
    this.title,
    this.icon = Icons.info_outline_rounded,
    this.accent = SettingsPalette.gold,
    this.onActionTap,
    this.actionLabel,
  });

  final String message;
  final String? title;
  final IconData icon;
  final Color accent;
  final VoidCallback? onActionTap;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.15),
            ),
            child: Icon(icon, size: 16, color: accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (title != null) ...<Widget>[
                  Text(
                    title!,
                    style: AppTextStyles.captionBold.copyWith(
                      color: accent,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: AppTextStyles.caption.copyWith(
                    color: SettingsPalette.textMid,
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (onActionTap != null && actionLabel != null) ...<Widget>[
            const SizedBox(width: 8),
            SettingsPressable(
              onTap: onActionTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: accent.withValues(alpha: 0.2),
                  border: Border.all(color: accent.withValues(alpha: 0.6)),
                ),
                child: Text(
                  actionLabel!,
                  style: AppTextStyles.captionBold.copyWith(
                    color: accent,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
