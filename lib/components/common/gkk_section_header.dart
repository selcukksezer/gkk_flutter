import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

/// 2027 Aion 2 Obsidian Glass & Luminescence design tokens.
abstract final class _Aion2Tokens {
  // Obsidian Glass Surface Palette
  static const Color obsidianVoid = Color(0xFF07090E);
  static const Color obsidianDeep = Color(0xFF0B0E14);
  static const Color obsidianSurface = Color(0xFF101522);

  // Celestial Gold (#E5C158) Luminescence
  static const Color celestialGold = Color(0xFFE5C158);
  static const Color celestialGoldLight = Color(0xFFFDE68A);
  static const Color celestialGoldGlow = Color(0x33E5C158);

  // Ether Cyan (#00E5FF) Luminescence
  static const Color etherCyan = Color(0xFF00E5FF);
  static const Color etherCyanGlow = Color(0x3300E5FF);
  static const Color etherCyanHalo = Color(0x6600E5FF);
}

/// A 2027 Aion 2 obsidian-glass styled section header with celestial gold wing
/// ornament, ether cyan luminous accent beacon, optional action button with
/// tactile [HapticFeedback.selectionClick()], and edge-to-edge SafeArea alignment.
///
/// Fully backwards-compatible with standard usage:
/// ```dart
/// GkkSectionHeader(
///   title: 'Aktif Görevler',
///   trailing: TextButton(onPressed: ..., child: Text('Tümünü Gör')),
/// )
/// ```
///
/// Or enhanced with native Aion 2 action button and subtitle:
/// ```dart
/// GkkSectionHeader(
///   title: 'Zindan Akınları',
///   subtitle: 'Seviye 45+ Efsanevi Karşılaşmalar',
///   actionLabel: 'Tümünü Gör',
///   onActionTap: () => ...,
/// )
/// ```
class GkkSectionHeader extends StatelessWidget {
  const GkkSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.icon,
    this.subtitle,
    this.actionLabel,
    this.onActionTap,
    this.actionIcon,
    this.showGlassBackdrop = true,
    this.showBeacon = true,
    this.showOrnament = true,
    this.padding,
    this.margin,
    this.titleStyle,
    this.subtitleStyle,
    this.useSafeArea = false,
  });

  /// Primary headline text of the section.
  final String title;

  /// Optional trailing widget (e.g. custom button, badge, count indicator).
  /// Takes precedence over [actionLabel] and [onActionTap] if provided.
  final Widget? trailing;

  /// Optional emoji or icon string displayed before the title.
  final String? icon;

  /// Optional secondary subtitle text rendered beneath the title.
  final String? subtitle;

  /// Optional label for the 2027 Aion 2 action button (e.g. 'Tümünü Gör', 'Yenile').
  /// Only rendered if [trailing] is null.
  final String? actionLabel;

  /// Optional callback invoked when the action button is tapped.
  /// Automatically triggers [HapticFeedback.selectionClick()].
  final VoidCallback? onActionTap;

  /// Optional custom icon for the action button (defaults to chevron_right).
  final IconData? actionIcon;

  /// Whether to render the frosted obsidian glass backdrop strip/pill with blur.
  /// Defaults to `true`. Set to `false` for a completely transparent layout.
  final bool showGlassBackdrop;

  /// Whether to display the Ether Cyan (#00E5FF) luminous accent beacon.
  /// Defaults to `true`.
  final bool showBeacon;

  /// Whether to display the Celestial Gold (#E5C158) typographic wing ornament.
  /// Defaults to `true`.
  final bool showOrnament;

  /// Inner padding of the section header. Defaults to ergonomic margin-aligned spacing.
  final EdgeInsetsGeometry? padding;

  /// Outer margin surrounding the section header container.
  final EdgeInsetsGeometry? margin;

  /// Custom text style override for the title.
  final TextStyle? titleStyle;

  /// Custom text style override for the subtitle.
  final TextStyle? subtitleStyle;

  /// Whether to wrap the header with [SafeArea] for notch/island edge protection.
  final bool useSafeArea;

  /// Static builder for a standalone 2027 Aion 2 obsidian-glass action pill button
  /// with integrated [HapticFeedback.selectionClick()].
  static Widget actionButton({
    required String label,
    required VoidCallback onTap,
    IconData icon = Icons.chevron_right_rounded,
    Color accentColor = _Aion2Tokens.etherCyan,
    Color labelColor = _Aion2Tokens.celestialGold,
  }) {
    return _Aion2ActionButton(
      label: label,
      onTap: onTap,
      icon: icon,
      accentColor: accentColor,
      labelColor: labelColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget? effectiveTrailing = trailing;
    if (effectiveTrailing == null && (onActionTap != null || actionLabel != null)) {
      effectiveTrailing = _Aion2ActionButton(
        label: actionLabel ?? 'Tümünü Gör',
        onTap: onActionTap,
        icon: actionIcon ?? Icons.chevron_right_rounded,
      );
    }

    final Widget leadingAndTitle = Expanded(
      child: Row(
        children: <Widget>[
          if (showBeacon) ...<Widget>[
            const _EtherCyanBeacon(),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (showOrnament) ...<Widget>[
            const _CelestialWingOrnament(),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (icon != null) ...<Widget>[
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(icon!, style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: titleStyle ??
                      AppTextStyles.h3.copyWith(
                        color: AppColors.textPrimary,
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w700,
                      ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: subtitleStyle ??
                        AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary.withValues(alpha: 0.85),
                          letterSpacing: 0.1,
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final Widget contentRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        leadingAndTitle,
        if (effectiveTrailing != null) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: effectiveTrailing,
            ),
          ),
        ],
      ],
    );

    Widget headerBody;
    if (showGlassBackdrop) {
      headerBody = Container(
        margin: margin ?? const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xCC101522),
              Color(0x990B0E14),
              Color(0xB307090E),
            ],
            stops: <double>[0.0, 0.55, 1.0],
          ),
          border: Border.all(
            color: const Color(0x3300E5FF).withValues(alpha: 0.22),
            width: 1.0,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1800E5FF),
              blurRadius: 16,
              spreadRadius: -4,
              offset: Offset(0, 2),
            ),
            BoxShadow(
              color: Color(0x12E5C158),
              blurRadius: 14,
              spreadRadius: -6,
              offset: Offset(0, -1),
            ),
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Stack(
              children: <Widget>[
                // Top crystalline specular hairline sheen
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 1.0,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.transparent,
                          Color(0x3300E5FF),
                          Color(0x59E5C158),
                          Color(0x3300E5FF),
                          Colors.transparent,
                        ],
                        stops: <double>[0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: padding ??
                      const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 10.0,
                      ),
                  child: contentRow,
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      headerBody = Container(
        margin: margin,
        padding: padding ?? const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: contentRow,
      );
    }

    if (useSafeArea) {
      return SafeArea(
        top: false,
        bottom: false,
        minimum: const EdgeInsets.symmetric(horizontal: 4.0),
        child: headerBody,
      );
    }

    return headerBody;
  }
}

/// Standalone 2027 Aion 2 obsidian-glass action pill button with tactile haptic feedback.
class _Aion2ActionButton extends StatelessWidget {
  const _Aion2ActionButton({
    required this.label,
    this.onTap,
    this.icon = Icons.chevron_right_rounded,
    this.accentColor = _Aion2Tokens.etherCyan,
    this.labelColor = _Aion2Tokens.celestialGold,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData icon;
  final Color accentColor;
  final Color labelColor;

  void _handleTap() {
    HapticFeedback.selectionClick();
    onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap != null ? _handleTap : null,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        splashColor: accentColor.withValues(alpha: 0.25),
        highlightColor: labelColor.withValues(alpha: 0.15),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm + 2,
            vertical: AppSpacing.xs + 1,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            gradient: LinearGradient(
              colors: <Color>[
                accentColor.withValues(alpha: 0.15),
                const Color(0x22101522),
                labelColor.withValues(alpha: 0.15),
              ],
              stops: const <double>[0.0, 0.5, 1.0],
            ),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.38),
              width: 1.0,
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: accentColor.withValues(alpha: 0.15),
                blurRadius: 8,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: AppTextStyles.captionBold.copyWith(
                      color: labelColor,
                      fontSize: 11.5,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                icon,
                size: 14,
                color: accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 2027 Aion 2 Ether Cyan (#00E5FF) radiant beacon indicator.
class _EtherCyanBeacon extends StatelessWidget {
  const _EtherCyanBeacon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(1.2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: _Aion2Tokens.etherCyan,
                blurRadius: 6,
                spreadRadius: 1.5,
              ),
              BoxShadow(
                color: _Aion2Tokens.etherCyanHalo,
                blurRadius: 10,
                spreadRadius: 2.5,
              ),
            ],
          ),
          transform: Matrix4.rotationZ(0.785398),
          transformAlignment: Alignment.center,
        ),
      ),
    );
  }
}

/// 2027 Aion 2 Celestial Gold (#E5C158) typographic wing ornament.
class _CelestialWingOrnament extends StatelessWidget {
  const _CelestialWingOrnament({
    this.color = _Aion2Tokens.celestialGold,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 14,
      child: CustomPaint(
        painter: _CelestialWingPainter(color: color),
      ),
    );
  }
}

class _CelestialWingPainter extends CustomPainter {
  const _CelestialWingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Ambient celestial gold glow
    final Paint glowPaint = Paint()
      ..color = color.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    // Sharp gold stroke
    final Paint goldStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;

    final Paint goldFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          _Aion2Tokens.celestialGoldLight,
          color,
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    // Left sweeping wing feather
    final Path leftWing = Path()
      ..moveTo(w * 0.45, h * 0.85)
      ..quadraticBezierTo(w * 0.18, h * 0.55, 0.0, h * 0.15)
      ..quadraticBezierTo(w * 0.22, h * 0.35, w * 0.45, h * 0.55)
      ..close();

    // Right sweeping wing feather
    final Path rightWing = Path()
      ..moveTo(w * 0.55, h * 0.85)
      ..quadraticBezierTo(w * 0.82, h * 0.55, w, h * 0.15)
      ..quadraticBezierTo(w * 0.78, h * 0.35, w * 0.55, h * 0.55)
      ..close();

    // Central Daeva crest diamond
    final Path crestDiamond = Path()
      ..moveTo(w * 0.5, h * 0.05)
      ..lineTo(w * 0.62, h * 0.35)
      ..lineTo(w * 0.5, h * 0.65)
      ..lineTo(w * 0.38, h * 0.35)
      ..close();

    canvas.drawPath(leftWing, glowPaint);
    canvas.drawPath(rightWing, glowPaint);
    canvas.drawPath(crestDiamond, glowPaint);

    canvas.drawPath(leftWing, goldFill);
    canvas.drawPath(rightWing, goldFill);
    canvas.drawPath(crestDiamond, goldFill);

    canvas.drawPath(leftWing, goldStroke);
    canvas.drawPath(rightWing, goldStroke);
    canvas.drawPath(crestDiamond, goldStroke);
  }

  @override
  bool shouldRepaint(covariant _CelestialWingPainter oldDelegate) =>
      oldDelegate.color != color;
}

